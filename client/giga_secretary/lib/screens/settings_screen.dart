import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../services/drive_service.dart';

class SettingsScreen extends StatefulWidget {
  final GoogleSignIn googleSignIn;
  final DriveService driveService;

  const SettingsScreen({
    super.key,
    required this.googleSignIn,
    required this.driveService,
  });

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  GoogleSignInAccount? _currentUser;
  bool _isSigningIn = false;
  String? _selectedFolderName;
  final TextEditingController _folderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeGoogleSignIn();
  }

  Future<void> _initializeGoogleSignIn() async {
    // Получаем текущего пользователя
    _currentUser = widget.googleSignIn.currentUser;

    // Подписываемся на изменения состояния авторизации
    widget.googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      setState(() {
        _currentUser = account;
      });
      if (_currentUser != null) {
        _loadSelectedFolder();
      }
    });

    // Пробуем тихую авторизацию
    try {
      _currentUser = await widget.googleSignIn.signInSilently();
      if (_currentUser != null) {
        await widget.driveService.initialize();
        await _loadSelectedFolder();
      }
    } catch (e) {
      print('Error during silent sign in: $e');
    }
  }

  @override
  void dispose() {
    _folderController.dispose();
    super.dispose();
  }

  Future<void> _loadSelectedFolder() async {
    if (_currentUser == null) return;

    final folderId = await widget.driveService.getSelectedFolderId();
    if (folderId != null) {
      await _getFolderName(folderId);
    }
  }

  Future<void> _getFolderName(String folderId) async {
    if (_currentUser == null) return;

    try {
      await widget.driveService.initialize();
      if (widget.driveService.driveApi == null) {
        throw Exception('DriveApi не инициализирован');
      }

      final folder = await widget.driveService.driveApi!.files.get(
        folderId,
        $fields: 'name',
      ) as drive.File;

      if (mounted) {
        setState(() {
          _selectedFolderName = folder.name ?? 'Неизвестная папка';
          _folderController.text = _selectedFolderName!;
        });
      }
    } catch (e) {
      print('Error fetching folder name: $e');
      if (mounted) {
        setState(() {
          _selectedFolderName = 'Не удалось загрузить имя папки';
          _folderController.text = _selectedFolderName!;
        });
      }
    }
  }

  Future<void> _signIn() async {
    if (_isSigningIn) return;

    setState(() {
      _isSigningIn = true;
    });

    try {
      final account = await widget.googleSignIn.signIn();
      if (account != null) {
        await widget.driveService.initialize();
        await _loadSelectedFolder();
      }
    } catch (e) {
      print('Error signing in: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при авторизации: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isSigningIn = true;
    });

    try {
      await widget.googleSignIn.signOut();
      if (mounted) {
        setState(() {
          _currentUser = null;
          _selectedFolderName = null;
          _folderController.clear();
        });
      }
    } catch (e) {
      print('Error signing out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при выходе: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  Future<void> _selectFolder() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, войдите в аккаунт')),
      );
      return;
    }

    await widget.driveService.initialize();
    if (widget.driveService.driveApi == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка доступа к Google Drive')),
      );
      return;
    }

    try {
      final files = await widget.driveService.driveApi!.files.list(
        q: "mimeType='application/vnd.google-apps.folder' and trashed=false",
        spaces: 'drive',
        $fields: 'files(id,name)',
      );

      final folders = files.files ?? [];

      if (folders.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Папки не найдены')),
          );
        }
        return;
      }

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A2157),
          title: const Text(
            'Выберите папку',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                return ListTile(
                  title: Text(
                    folder.name ?? 'Неизвестная папка',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (folder.id != null) {
                      _saveFolder(folder.id!);
                      setState(() {
                        _selectedFolderName = folder.name;
                        _folderController.text = folder.name ?? '';
                      });
                    }
                  },
                );
              },
            ),
          ),
        ),
      );
    } catch (e) {
      print('Error fetching folders: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при получении папок: $e')),
        );
      }
    }
  }

  Future<void> _saveFolder(String folderId) async {
    try {
      await widget.driveService.setSelectedFolderId(folderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Папка успешно сохранена')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error saving folder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при сохранении папки: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D162D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2157),
        title: const Text('Настройки', style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: const Color(0xFF1A2157),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Аккаунт Google',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_currentUser != null) ...[
                      Text(
                        'Вы вошли как: ${_currentUser!.email}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isSigningIn ? null : _signOut,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: _isSigningIn
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Выйти'),
                      ),
                    ] else ...[
                      const Text(
                        'Войдите в аккаунт для доступа к Google Drive',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isSigningIn ? null : _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: _isSigningIn
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Войти'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_currentUser != null)
              Card(
                color: const Color(0xFF1A2157),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Папка для сохранения',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedFolderName ?? 'Папка не выбрана',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _selectFolder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Выбрать папку'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
