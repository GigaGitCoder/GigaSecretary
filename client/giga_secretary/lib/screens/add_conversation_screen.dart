import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../models/conversation.dart';
import '../services/conversation_service.dart';
import '../services/drive_service.dart';
import '../widgets/audio_progress_bar.dart';

class AddConversationScreen extends StatefulWidget {
  final DriveService driveService;
  final ConversationService conversationService;

  const AddConversationScreen({
    Key? key,
    required this.driveService,
    required this.conversationService,
  }) : super(key: key);

  @override
  State<AddConversationScreen> createState() => _AddConversationScreenState();
}

class _AddConversationScreenState extends State<AddConversationScreen> {
  final _titleController = TextEditingController();
  bool _isUploading = false;
  double _uploadProgress = 0;
  String? _errorMessage;
  String? _statusMessage;
  bool _isCancelled = false;
  File? _selectedFile;
  String? _selectedFileName;
  int? _selectedFileSize;
  Duration? _selectedFileDuration;
  bool _isTitleAvailable = true;
  bool _isCheckingTitle = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _resetUpload() {
    if (mounted) {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0;
        _errorMessage = null;
        _statusMessage = null;
        _isCancelled = true;
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _checkTitleAvailability() async {
    if (_titleController.text.isEmpty) {
      setState(() => _isTitleAvailable = true);
      return;
    }

    setState(() => _isCheckingTitle = true);
    
    try {
      final isAvailable = await widget.conversationService.isTitleAvailable(_titleController.text);
      if (mounted) {
        setState(() => _isTitleAvailable = isAvailable);
      }
    } catch (e) {
      print('Error checking title: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingTitle = false);
      }
    }
  }

  Future<void> _selectFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = File(result.files.first.path!);
    final fileSize = await file.length();
    
    setState(() {
      _selectedFile = file;
      _selectedFileName = result.files.first.name;
      _selectedFileSize = fileSize;
      _errorMessage = null;
    });

    // Проверяем длительность аудио
    final player = AudioPlayer();
    try {
      await player.setFilePath(file.path);
      final duration = await player.duration;
      
      if (mounted) {
        setState(() => _selectedFileDuration = duration);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Ошибка при чтении аудио файла: $e');
      }
    } finally {
      await player.dispose();
    }
  }

  Future<void> _saveConversation() async {
    if (_selectedFile == null) {
      setState(() => _errorMessage = 'Пожалуйста, выберите аудио файл');
      return;
    }

    if (_titleController.text.isEmpty) {
      setState(() => _errorMessage = 'Пожалуйста, введите название записи');
      return;
    }

    if (!_isTitleAvailable) {
      setState(() => _errorMessage = 'Запись с таким названием уже существует');
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
      _statusMessage = 'Загрузка файла...';
      _isCancelled = false;
      _uploadProgress = 0;
    });

    try {
      await widget.conversationService.saveConversation(
        _selectedFile!,
        _titleController.text,
        onProgress: (progress) {
          if (mounted && !_isCancelled) {
            setState(() {
              _uploadProgress = progress;
              _statusMessage = 'Загрузка файла: ${(progress * 100).toStringAsFixed(1)}%\n'
                  'Размер: ${_formatFileSize(_selectedFileSize!)}';
            });
          }
        },
      );

      if (_isCancelled) return;

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted && !_isCancelled) {
        setState(() {
          _errorMessage = e.toString();
          _isUploading = false;
          _statusMessage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isUploading) {
          final shouldCancel = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1A2157),
              title: const Text(
                'Отменить загрузку?',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                'Вы уверены, что хотите отменить загрузку?',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Продолжить загрузку'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Отменить',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );
          if (shouldCancel == true) {
            _resetUpload();
          }
          return false;
        }
        return true;
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF0D162D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2157),
          title: const Text('Новая запись', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                enabled: !_isUploading,
                onChanged: (_) => _checkTitleAvailability(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Название',
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  errorText: !_isTitleAvailable ? 'Это название уже занято' : null,
                  suffixIcon: _isCheckingTitle
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              if (_selectedFile != null) ...[
                Card(
                  color: const Color(0xFF1A2157),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Выбранный файл:',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedFileName ?? 'Неизвестный файл',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Размер: ${_formatFileSize(_selectedFileSize!)}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        if (_selectedFileDuration != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Длительность: ${_formatDuration(_selectedFileDuration!)}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_isUploading) ...[
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Загрузка файла...',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _resetUpload,
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  label: const Text(
                    'Отменить загрузку',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ] else ...[
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
                ],
                ElevatedButton.icon(
                  onPressed: _selectFile,
                  icon: const Icon(Icons.audio_file),
                  label: const Text('Выбрать аудиофайл'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                if (_selectedFile != null) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isTitleAvailable ? _saveConversation : null,
                    icon: const Icon(Icons.save),
                    label: const Text('Сохранить'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
