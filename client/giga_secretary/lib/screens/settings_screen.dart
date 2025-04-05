import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
    ],
  );

  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;
  bool _isSigningIn = false;
  String? _selectedFolderName;
  final TextEditingController _folderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      setState(() {
        _currentUser = account;
      });
      if (_currentUser != null) {
        _initializeDriveApi();
      }
    });

    _googleSignIn.signInSilently().then((_) {
      if (_currentUser != null && _driveApi == null) {
        _initializeDriveApi();
      }
    });

    _loadSelectedFolder();
  }

  @override
  void dispose() {
    _folderController.dispose(); // Освобождаем ресурсы контроллера
    super.dispose();
  }

  Future<void> _initializeDriveApi() async {
    if (_currentUser == null) {
      print('No user signed in');
      return;
    }

    try {
      final GoogleSignInAuthentication auth = await _currentUser!.authentication;

      if (auth.accessToken == null) {
        print('No access token available');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка: токен доступа не получен. Попробуйте снова.')),
        );
        await _googleSignIn.signOut();
        setState(() {
          _currentUser = null;
          _driveApi = null;
        });
        return;
      }

      final credentials = AccessCredentials(
        AccessToken(
          'Bearer',
          auth.accessToken!,
          DateTime.now().add(const Duration(hours: 1)).toUtc(),
        ),
        null,
        _googleSignIn.scopes,
      );

      final client = authenticatedClient(
        http.Client(),
        credentials,
      );

      setState(() {
        _driveApi = drive.DriveApi(client);
      });

      // После успешной инициализации API, попробуем загрузить имя папки
      final prefs = await SharedPreferences.getInstance();
      final folderId = prefs.getString('googleDriveFolderId');
      if (folderId != null) {
        await _getFolderName(folderId);
      }
    } catch (e) {
      print('Error initializing Drive API: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка при инициализации Google Drive API. Попробуйте снова.')),
      );
      setState(() {
        _driveApi = null;
      });
    }
  }

  Future<void> _loadSelectedFolder() async {
    final prefs = await SharedPreferences.getInstance();
    final folderId = prefs.getString('googleDriveFolderId');
    if (folderId != null) {
      await _getFolderName(folderId);
    }
  }

  Future<void> _getFolderName(String folderId) async {
    if (_driveApi == null) {
      setState(() {
        _selectedFolderName = 'Не удалось загрузить имя папки';
        _folderController.text = _selectedFolderName!;
      });
      return;
    }

    try {
      final folder = await _driveApi!.files.get(
        folderId,
        $fields: 'name',
      );

      final driveFile = folder as drive.File;

      setState(() {
        _selectedFolderName = driveFile.name ?? 'Неизвестная папка';
        _folderController.text = _selectedFolderName!;
      });
    } catch (e) {
      print('Error fetching folder name: $e');
      setState(() {
        _selectedFolderName = 'Не удалось загрузить имя папки';
        _folderController.text = _selectedFolderName!;
      });
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _isSigningIn = true;
    });

    try {
      await _googleSignIn.signIn();
      if (_currentUser != null) {
        await _initializeDriveApi();
      }
    } catch (e) {
      print('Error signing in: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при авторизации. Попробуйте снова.')),
      );
    } finally {
      setState(() {
        _isSigningIn = false;
      });
    }
  }

  Future<void> _signOut() async {
    await _googleSignIn.signOut();
    setState(() {
      _currentUser = null;
      _driveApi = null;
      _selectedFolderName = null;  // Очистить выбранную папку
      _folderController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Вы успешно вышли из аккаунта.')),
    );
  }

  Future<void> _selectFolder() async {
    if (_driveApi == null) {
      print('You need to sign in first!');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Пожалуйста, войдите в свою учетную запись.')),
      );
      return;
    }

    try {
      final files = await _driveApi!.files.list(
        q: "trashed=false",  // Игнорируем все элементы в корзине
        spaces: 'drive',
      );

      final folders = files.files?.where((file) => file.mimeType == 'application/vnd.google-apps.folder').toList() ?? [];

      if (folders.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Выберите папку'),
            content: Container(
              width: double.maxFinite, // Позволяет контейнеру занять доступную ширину
              height: 300, // Ограничиваем высоту контейнера
              child: ListView(
                children: folders
                    .map(
                      (folder) => ListTile(
                        title: Text(folder.name ?? 'Неизвестная папка'),
                        onTap: () {
                          Navigator.pop(context);
                          _saveFolder(folder.id!);
                          setState(() {
                            _selectedFolderName = folder.name ?? 'Неизвестная папка'; // Обновляем выбранную папку
                            _folderController.text = _selectedFolderName!; // Обновляем текст контроллера
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        );
      } else {
        print('No folders found');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Папки не найдены.')),
        );
      }
    } catch (e) {
      print('Error fetching folders: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при получении папок. Попробуйте позже.')),
      );
    }
  }

  Future<void> _saveFolder(String folderId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('googleDriveFolderId', folderId);
    print('Folder saved: $folderId');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Папка успешно сохранена!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D162D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2157),
        title: const Text('Настройки', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text('Аккаунт на Google:', style: TextStyle(color: Colors.white)),
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Вы вошли как:',
                  hintStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Color(0xFF1A2157),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                readOnly: true,
                controller: TextEditingController(
                  text: _currentUser != null ? _currentUser!.email : 'Не авторизован',
                ),
                onTap: _isSigningIn || _currentUser != null ? null : _signIn,
              ),
              const SizedBox(height: 16),
              const Text('Папка на Google Диске:', style: TextStyle(color: Colors.white)),
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Выберите папку для сохранения',
                  hintStyle: TextStyle(color: Colors.white70),
                  filled: true,
                                    fillColor: Color(0xFF1A2157),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                readOnly: true,
                controller: _folderController, // Используем контроллер здесь
                onTap: _isSigningIn || _driveApi == null ? null : _selectFolder,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isSigningIn || _driveApi == null ? null : _selectFolder,
                child: const Text('Выбрать папку для сохранения'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isSigningIn
                    ? null
                    : (_currentUser == null ? _signIn : _signOut),
                child: Text(_currentUser == null ? 'Войти' : 'Выйти'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
