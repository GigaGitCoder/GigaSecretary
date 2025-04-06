import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import '../models/conversation.dart';
import 'drive_service.dart';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ConversationService {
  static const int _maxFileSizeBytes = 2 * 1024 * 1024 * 1024; // 2 GB
  static const Duration _maxDuration = Duration(minutes: 10);
  
  final DriveService _driveService;
  
  ConversationService(this._driveService);
  
  Future<List<Conversation>> getConversations() async {
    if (_driveService.driveApi == null) {
      throw Exception('Drive API не инициализирован');
    }

    final folderId = await _driveService.getSelectedFolderId();
    if (folderId == null) {
      throw Exception('Папка не выбрана');
    }

    try {
      final files = await _driveService.driveApi!.files.list(
        q: "('$folderId' in parents) and (mimeType contains 'audio/' or mimeType contains 'video/') and trashed=false",
        spaces: 'drive',
        $fields: 'files(id,name,createdTime,size,mimeType)',
        orderBy: 'createdTime desc',
      );

      final conversations = files.files?.map((file) {
        final createdAt = DateTime.parse(file.createdTime?.toString() ?? '');
        final isVideo = file.mimeType?.contains('video') ?? false;
        
        return Conversation(
          id: file.id ?? '',
          title: file.name ?? '',
          createdAt: createdAt,
          size: int.tryParse(file.size ?? '0') ?? 0,
          isVideo: isVideo,
          fileId: file.id ?? '',
        );
      }).toList() ?? [];

      return Future.value(conversations);
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      rethrow;
    }
  }

  Future<bool> isTitleAvailable(String title) async {
    try {
      final files = await _driveService.listFiles();
      final fileName = '$title.mp3';
      return !files.any((file) => file.name == fileName);
    } catch (e) {
      debugPrint('Error checking title availability: $e');
      return false;
    }
  }
  
  Future<void> saveConversation(
    File file,
    String title, {
    Function(double)? onProgress,
  }) async {
    // Проверяем доступность названия
    if (!await isTitleAvailable(title)) {
      throw Exception('Запись с таким названием уже существует');
    }

    final fileSize = await file.length();
    final fileName = file.path.toLowerCase();
    final isVideo = fileName.endsWith('.mp4') || 
                    fileName.endsWith('.mov') || 
                    fileName.endsWith('.avi');
    
    // Проверяем размер файла
    if (fileSize > _maxFileSizeBytes) {
      throw Exception('Файл слишком большой. Максимальный размер: 2 ГБ');
    }

    // Проверяем длительность только для аудио файлов
    if (!isVideo) {
      final player = AudioPlayer();
      try {
        await player.setFilePath(file.path);
        final duration = player.duration;
        
        if (duration == null) {
          throw Exception('Не удалось определить длительность аудио');
        }
        
        if (duration > _maxDuration) {
          throw Exception('Аудио слишком длинное. Максимальная длительность: 10 минут');
        }
      } finally {
        await player.dispose();
      }
    }

    final extension = path.extension(file.path).toLowerCase();
    final outputFileName = '$title$extension';
    final fileStream = file.openRead();
    final streamController = StreamController<List<int>>();
    
    var bytesUploaded = 0;
    String? fileId;
    
    try {
      // Настраиваем обработку потока данных
      fileStream.listen(
        (chunk) {
          bytesUploaded += chunk.length;
          if (onProgress != null) {
            onProgress(bytesUploaded / fileSize);
          }
          streamController.add(chunk);
        },
        onDone: () => streamController.close(),
        onError: (error) {
          streamController.addError(error);
          streamController.close();
        },
        cancelOnError: true,
      );

      // Загружаем файл
      fileId = await _driveService.uploadFile(
        file,
        outputFileName,
        fileStream: streamController.stream,
        fileSize: fileSize,
      );

      if (fileId == null) {
        throw Exception('Не удалось получить идентификатор загруженного файла');
      }

      // Обновляем список записей
      await getConversations();
      
    } catch (e) {
      // Если произошла ошибка и файл был загружен, удаляем его
      if (fileId != null) {
        try {
          await _driveService.deleteFile(fileId);
        } catch (deleteError) {
          debugPrint('Error deleting file after failed upload: $deleteError');
        }
      }
      
      // Закрываем контроллер если он еще открыт
      if (!streamController.isClosed) {
        await streamController.close();
      }
      
      rethrow;
    }
  }
  
  Future<void> deleteConversation(String id) async {
    await _driveService.deleteFile(id);
  }

  Future<Map<String, dynamic>?> processAudio(String fileId, String fileName) async {
    try {
      debugPrint('Starting processAudio for fileId: $fileId, fileName: $fileName');
      
      // Получаем информацию о файле, чтобы узнать его название
      final files = await _driveService.listFiles();
      final audioFile = files.firstWhere(
        (file) => file.id == fileId,
        orElse: () => throw Exception('Файл не найден'),
      );
      
      // Используем название файла без расширения как базовое имя
      final baseFileName = audioFile.name?.split('.').first ?? 'unknown';
      
      final url = await _driveService.getFileDownloadUrl(fileId);
      if (url == null) {
        debugPrint('Failed to get download URL');
        throw Exception('Не удалось получить URL файла');
      }
      debugPrint('Got download URL: $url');

      // Получаем заголовки авторизации
      final authHeaders = await _driveService.getAuthHeaders();
      if (authHeaders == null) {
        debugPrint('Failed to get auth headers');
        throw Exception('Не удалось получить заголовки авторизации');
      }
      debugPrint('Got auth headers');

      debugPrint('Downloading file from Google Drive...');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          ...authHeaders,
          'Accept': '*/*',
        },
      );
      if (response.statusCode != 200) {
        debugPrint('Failed to download file. Status code: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        throw Exception('Не удалось загрузить файл');
      }
      debugPrint('File downloaded successfully. Size: ${response.bodyBytes.length} bytes');

      const apiUrl = 'http://yourIp:Port/process_audio/'; // Тут вставляем адрес сервера
      debugPrint('Sending file to API: $apiUrl');
      
      final request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          response.bodyBytes,
          filename: fileName,
        ),
      );

      debugPrint('Sending request to API...');
      final apiResponse = await request.send().timeout(
        const Duration(minutes: 30),
        onTimeout: () {
          throw Exception('Превышено время ожидания ответа от сервера');
        },
      );
      
      debugPrint('Got API response. Status code: ${apiResponse.statusCode}');
      if (apiResponse.statusCode != 200) {
        final errorBody = await apiResponse.stream.bytesToString();
        debugPrint('API error response: $errorBody');
        throw Exception('Ошибка API: ${apiResponse.statusCode}\nОтвет: $errorBody');
      }

      debugPrint('Reading response body...');
      final responseBody = await apiResponse.stream.bytesToString();
      debugPrint('Response body length: ${responseBody.length}');
      debugPrint('Response from server: $responseBody');
      
      final result = jsonDecode(responseBody);
      debugPrint('Successfully parsed JSON response');
      debugPrint('Parsed result: $result');

      // Проверяем структуру ответа
      if (result is! Map<String, dynamic>) {
        throw Exception('Неверный формат ответа от сервера');
      }

      if (!result.containsKey('speakers') || !result.containsKey('events') || !result.containsKey('duties')) {
        throw Exception('Отсутствуют обязательные поля в ответе сервера');
      }

      // Сохраняем результат в файл на Google Drive
      final resultFileName = '${baseFileName}_analysis.json';
      debugPrint('Saving analysis result as: $resultFileName');
      
      final folderId = await _driveService.getSelectedFolderId();
      if (folderId == null) {
        throw Exception('Папка не выбрана');
      }

      // Преобразуем данные в UTF-8 байты один раз
      final bytes = utf8.encode(responseBody);
      
      // Загружаем результат напрямую из байтов
      final resultFile = await _driveService.uploadFile(
        null,
        resultFileName,
        fileStream: Stream.value(bytes),
        fileSize: bytes.length,
      );

      if (resultFile == null) {
        throw Exception('Не удалось сохранить результат анализа');
      }
      debugPrint('Analysis result saved successfully');

      return result;
    } catch (e, stackTrace) {
      debugPrint('Error in processAudio: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAnalysis(String fileId) async {
    try {
      // Ждем инициализации Drive API
      await _driveService.initialize();
      
      debugPrint('Getting analysis for file: $fileId');
      final files = await _driveService.listFiles();
      final audioFile = files.firstWhere(
        (file) => file.id == fileId,
        orElse: () => throw Exception('Файл не найден'),
      );

      // Используем название файла без расширения как базовое имя
      final baseFileName = audioFile.name?.split('.').first ?? 'unknown';
      final analysisFileName = '${baseFileName}_analysis.json';
      
      debugPrint('Looking for analysis file: $analysisFileName');
      
      final analysisFile = files.firstWhere(
        (file) => file.name == analysisFileName,
        orElse: () => throw Exception('Файл анализа не найден'),
      );
      
      debugPrint('Found analysis file with ID: ${analysisFile.id}');

      final url = await _driveService.getFileDownloadUrl(analysisFile.id!);
      if (url == null) {
        throw Exception('Не удалось получить URL файла анализа');
      }
      debugPrint('Got download URL for analysis file');

      // Получаем заголовки авторизации
      final authHeaders = await _driveService.getAuthHeaders();
      if (authHeaders == null) {
        debugPrint('Failed to get auth headers');
        throw Exception('Не удалось получить заголовки авторизации');
      }
      debugPrint('Got auth headers for analysis file');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          ...authHeaders,
          'Accept': '*/*',
        },
      );
      
      if (response.statusCode != 200) {
        debugPrint('Failed to download analysis file. Status code: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        throw Exception('Не удалось загрузить файл анализа');
      }
      
      debugPrint('Successfully downloaded analysis file. Size: ${response.bodyBytes.length} bytes');
      
      // Декодируем ответ как UTF-8
      final String decodedBody = utf8.decode(response.bodyBytes);
      final result = jsonDecode(decodedBody);
      
      debugPrint('Successfully parsed analysis JSON');
      debugPrint('Analysis content: $result');
      return result;
    } catch (e, stackTrace) {
      debugPrint('Error getting analysis: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }
} 