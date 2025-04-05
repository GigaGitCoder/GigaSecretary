import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/conversation.dart';
import '../services/conversation_service.dart';
import '../services/drive_service.dart';
import 'add_conversation_screen.dart';
import 'conversation_detail_screen.dart';
import 'settings_screen.dart';

class ConversationListScreen extends StatefulWidget {
  final DriveService driveService;
  final ConversationService conversationService;
  final GoogleSignIn googleSignIn;

  const ConversationListScreen({
    Key? key,
    required this.driveService,
    required this.conversationService,
    required this.googleSignIn,
  }) : super(key: key);

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  List<Conversation>? _conversations;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    if (_isRetrying) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isRetrying = true;
    });

    try {
      // Сначала проверяем инициализацию DriveService
      await widget.driveService.initialize();
      
      // Затем загружаем список записей
      final conversations = await widget.conversationService.getConversations();
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
          _isRetrying = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка при загрузке записей: $e';
          _isLoading = false;
          _isRetrying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D162D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2157),
        title: const Text('Записи', style: TextStyle(color: Colors.white)),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    driveService: widget.driveService,
                    googleSignIn: widget.googleSignIn,
                  ),
                ),
              );
              if (result == true) {
                await _loadConversations();
              }
            },
            color: Colors.white,
          ),
        ],
        elevation: 0,
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Проверяем, выбрана ли папка
          final folderId = await widget.driveService.getSelectedFolderId();
          if (folderId == null) {
            if (mounted) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1A2157),
                  title: const Text(
                    'Настройки не заданы',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: const Text(
                    'Пожалуйста, выберите папку для сохранения в настройках',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SettingsScreen(
                              driveService: widget.driveService,
                              googleSignIn: widget.googleSignIn,
                            ),
                          ),
                        );
                        if (result == true) {
                          await _loadConversations();
                        }
                      },
                      child: const Text(
                        'Открыть настройки',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              );
              return;
            }
          }
          
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddConversationScreen(
                driveService: widget.driveService,
                conversationService: widget.conversationService,
              ),
            ),
          );
          if (result == true) {
            setState(() => _isLoading = true);
            await _loadConversations();
          }
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _conversations == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            SizedBox(height: 16),
            Text(
              'Загрузка записей...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isRetrying ? null : _loadConversations,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить попытку'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_conversations?.isEmpty ?? true) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.note_add,
              color: Colors.white30,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Нет записей',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Нажмите + чтобы добавить запись',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      color: Colors.blue,
      backgroundColor: const Color(0xFF1A2157),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _conversations!.length,
        itemBuilder: (context, index) {
          final conversation = _conversations![index];
          return Card(
            color: const Color(0xFF1A2157),
            elevation: 2,
            margin: const EdgeInsets.symmetric(
              vertical: 4,
              horizontal: 8,
            ),
            child: ListTile(
              title: Text(
                conversation.title,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Создано: ${conversation.createdAt.toLocal().toString().split('.')[0]}',
                style: const TextStyle(color: Colors.white70),
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.delete,
                  color: Colors.red,
                ),
                onPressed: () => _deleteConversation(conversation),
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConversationDetailScreen(
                      conversation: conversation,
                      driveService: widget.driveService,
                    ),
                  ),
                );
                _loadConversations();
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteConversation(Conversation conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2157),
        title: const Text(
          'Подтверждение',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Вы уверены, что хотите удалить эту запись?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await widget.conversationService.deleteConversation(conversation.id);
        await _loadConversations();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Запись успешно удалена')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Ошибка при удалении записи: $e';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка при удалении записи: $e')),
          );
        }
      }
    }
  }
}
