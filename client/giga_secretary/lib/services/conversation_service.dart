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
    try {
      // Получаем список файлов с Google Drive с дополнительными полями
      final driveFiles = await _driveService.listFilesWithDetails();
      
      // Очищаем текущий список
      _conversations.clear();
      
      // Создаем записи на основе файлов с диска
      for (final file in driveFiles) {
        if (file.id != null && file.name != null && file.createdTime != null) {
          // Отладочный вывод для проверки времени
          print('File: ${file.name}');
          print('UTC time: ${file.createdTime}');
          
          // Используем UTC время и преобразуем его в локальное
          final utcTime = DateTime.parse(file.createdTime!.toIso8601String());
          final localTime = utcTime.toLocal();
          
          print('Local time: $localTime');
          
          _conversations.add(Conversation(
            id: file.id!,
            title: file.name!.replaceAll('.mp3', ''),
            fileId: file.id!,
            createdAt: localTime,
          ));
        }
      }
      
      // Сортируем записи по дате создания (новые сверху)
      _conversations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return _conversations;
    } catch (e) {
      print('Error loading conversations: $e');
      return _conversations;
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
    File audioFile,
    String title, {
    Function(double)? onProgress,
  }) async {
    // Проверяем доступность названия
    if (!await isTitleAvailable(title)) {
      throw Exception('Запись с таким названием уже существует');
    }

    final fileSize = await audioFile.length();
    
    // Проверяем размер файла
    if (fileSize > _maxFileSizeBytes) {
      throw Exception('Файл слишком большой. Максимальный размер: 2 ГБ');
    }

    // Проверяем длительность аудио
    final player = AudioPlayer();
    try {
      await player.setFilePath(audioFile.path);
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

    final fileName = '$title.mp3';
    final fileStream = audioFile.openRead();
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
        audioFile,
        fileName,
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