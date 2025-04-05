import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class DriveService {
  static const String _folderIdKeyPrefix = 'googleDriveFolderId_';
  final GoogleSignIn _googleSignIn;
  drive.DriveApi? _driveApi;
  bool _isInitializing = false;

  DriveService(this._googleSignIn) {
    // Добавляем необходимые области доступа
    _googleSignIn.scopes.addAll([
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/drive.readonly',
      'https://www.googleapis.com/auth/drive.metadata.readonly',
    ]);
  }

  drive.DriveApi? get driveApi => _driveApi;

  String _getFolderIdKey() {
    final email = _googleSignIn.currentUser?.email;
    if (email == null) {
      throw Exception('Пользователь не авторизован');
    }
    return _folderIdKeyPrefix + email;
  }

  Future<void> initialize() async {
    if (_isInitializing) {
      print('Инициализация уже выполняется');
      return;
    }
    
    _isInitializing = true;
    try {
      print('Начало инициализации Drive API');
      print('Текущий пользователь: ${_googleSignIn.currentUser?.email}');
      
      // Сбрасываем текущий _driveApi
      _driveApi = null;
      
      final account = await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
      if (account != null) {
        print('Пользователь авторизован: ${account.email}');
        print('Области доступа: ${_googleSignIn.scopes}');
        await _initializeDriveApi(account);
      } else {
        print('Пользователь не авторизован');
      }
    } catch (e) {
      print('Ошибка при инициализации Drive API: $e');
      _driveApi = null;
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _initializeDriveApi(GoogleSignInAccount account) async {
    try {
      print('Получение токена доступа...');
      final auth = await account.authentication;
      if (auth.accessToken == null) {
        print('Не удалось получить токен доступа');
        throw Exception('Не удалось получить токен доступа');
      }
      print('Токен доступа получен успешно');

      print('Создание клиента Drive API...');
      final credentials = AccessCredentials(
        AccessToken(
          'Bearer',
          auth.accessToken!,
          DateTime.now().add(const Duration(hours: 1)).toUtc(),
        ),
        null,
        _googleSignIn.scopes,
      );

      final client = authenticatedClient(http.Client(), credentials);
      _driveApi = drive.DriveApi(client);
      print('Drive API успешно инициализирован для пользователя ${account.email}');
    } catch (e) {
      print('Ошибка при инициализации Drive API: $e');
      _driveApi = null;
      rethrow;
    }
  }

  Future<String?> getSelectedFolderId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_getFolderIdKey());
  }

  Future<void> setSelectedFolderId(String folderId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_getFolderIdKey(), folderId);
  }

  Future<String?> uploadFile(
    File file,
    String fileName, {
    Stream<List<int>>? fileStream,
    int? fileSize,
  }) async {
    await initialize();
    
    if (_driveApi == null) {
      throw Exception('Пожалуйста, войдите в аккаунт Google в настройках');
    }

    final folderId = await getSelectedFolderId();
    if (folderId == null) {
      throw Exception('Пожалуйста, выберите папку для сохранения в настройках');
    }

    // Проверяем существование папки перед загрузкой
    try {
      await _driveApi!.files.get(folderId);
    } catch (e) {
      throw Exception('Выбранная папка не найдена. Пожалуйста, выберите другую папку в настройках.');
    }

    try {
      final fileMetadata = drive.File()
        ..name = fileName
        ..parents = [folderId];

      // Проверяем размер файла
      final actualFileSize = fileSize ?? await file.length();
      if (actualFileSize <= 0) {
        throw Exception('Файл пуст');
      }

      // Проверяем доступность файла для чтения
      if (!await file.exists()) {
        throw Exception('Файл не найден');
      }

      final media = drive.Media(
        fileStream ?? file.openRead(),
        actualFileSize,
      );

      final response = await _driveApi!.files.create(
        fileMetadata,
        uploadMedia: media,
        $fields: 'id,name,size',
      );

      if (response.id == null) {
        throw Exception('Не удалось загрузить файл');
      }

      // Проверяем, что файл действительно загружен
      final uploadedFile = await _driveApi!.files.get(
        response.id!,
        $fields: 'size',
      ) as drive.File;

      final uploadedSize = int.tryParse(uploadedFile.size ?? '0') ?? 0;
      if (uploadedSize != actualFileSize) {
        // Если размеры не совпадают, удаляем файл и выбрасываем исключение
        await _driveApi!.files.delete(response.id!);
        throw Exception('Ошибка при проверке загруженного файла: размеры не совпадают');
      }

      return response.id;
    } catch (e) {
      print('Error uploading file: $e');
      rethrow;
    }
  }

  Future<String?> getFileDownloadUrl(String fileId) async {
    await initialize();
    
    if (_driveApi == null) {
      throw Exception('Пожалуйста, войдите в аккаунт Google в настройках');
    }

    try {
      // Получаем метаданные файла и прямую ссылку для скачивания
      final file = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
        $fields: 'id,name',
      ) as drive.Media;

      // Используем безопасный URL для скачивания
      return 'https://www.googleapis.com/drive/v3/files/$fileId?alt=media&key=${await _getApiKey()}';
    } catch (e) {
      print('Error getting file download URL: $e');
      if (e.toString().contains('Not Found')) {
        throw Exception('Файл не найден');
      }
      rethrow;
    }
  }

  Future<String> _getApiKey() async {
    final account = await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
    if (account == null) {
      throw Exception('Не удалось получить доступ к аккаунту');
    }
    final auth = await account.authentication;
    return auth.accessToken ?? '';
  }

  Future<List<drive.File>> listFiles() async {
    await initialize();
    
    if (_driveApi == null) {
      throw Exception('Пожалуйста, войдите в аккаунт Google в настройках');
    }

    final folderId = await getSelectedFolderId();
    if (folderId == null) {
      throw Exception('Папка не выбрана');
    }

    try {
      final response = await _driveApi!.files.list(
        q: "'$folderId' in parents and trashed = false",
        spaces: 'drive',
      );

      return response.files ?? [];
    } catch (e) {
      print('Error listing files: $e');
      if (e.toString().contains('Not Found')) {
        throw Exception('Выбранная папка не найдена. Пожалуйста, выберите другую папку в настройках.');
      }
      rethrow;
    }
  }

  Future<List<drive.File>> listFilesWithDetails() async {
    await initialize();
    
    if (_driveApi == null) {
      throw Exception('Пожалуйста, войдите в аккаунт Google в настройках');
    }

    final folderId = await getSelectedFolderId();
    if (folderId == null) {
      throw Exception('Папка не выбрана');
    }

    try {
      final response = await _driveApi!.files.list(
        q: "'$folderId' in parents and trashed = false",
        spaces: 'drive',
        $fields: 'files(id,name,createdTime,size)',
        orderBy: 'createdTime desc',
      );

      return response.files ?? [];
    } catch (e) {
      print('Error listing files: $e');
      if (e.toString().contains('Not Found')) {
        throw Exception('Выбранная папка не найдена. Пожалуйста, выберите другую папку в настройках.');
      }
      rethrow;
    }
  }

  Future<void> deleteFile(String fileId) async {
    await initialize();
    
    if (_driveApi == null) {
      throw Exception('Пожалуйста, войдите в аккаунт Google в настройках');
    }

    try {
      await _driveApi!.files.delete(fileId);
    } catch (e) {
      print('Error deleting file: $e');
      if (e.toString().contains('Not Found')) {
        // Если файл не найден, считаем что он уже удален
        return;
      }
      rethrow;
    }
  }

  Future<Map<String, String>?> getAuthHeaders() async {
    await initialize();
    
    if (_driveApi == null) {
      return null;
    }

    try {
      final account = await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
      if (account == null) {
        return null;
      }

      final auth = await account.authentication;
      if (auth.accessToken == null) {
        return null;
      }

      return {
        'Authorization': 'Bearer ${auth.accessToken}',
      };
    } catch (e) {
      print('Error getting auth headers: $e');
      return null;
    }
  }
} 