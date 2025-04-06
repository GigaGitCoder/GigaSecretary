import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/conversation.dart';
import 'drive_service.dart';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:just_audio/just_audio.dart';

class ConversationService {
  static const String _conversationsKey = 'conversations';
  static const int _maxFileSizeBytes = 2 * 1024 * 1024 * 1024; // 2 GB
  static const Duration _maxDuration = Duration(minutes: 10);
  
  final DriveService _driveService;
  final List<Conversation> _conversations = [];
  
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
      print('Error loading conversations: $e');
      rethrow;
    }
  }

  Future<bool> isTitleAvailable(String title) async {
    try {
      final files = await _driveService.listFiles();
      final fileName = '$title.mp3';
      return !files.any((file) => file.name == fileName);
    } catch (e) {
      print('Error checking title availability: $e');
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
        final duration = await player.duration;
        
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
          print('Error deleting file after failed upload: $deleteError');
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
    _conversations.removeWhere((c) => c.id == id);
  }
} 