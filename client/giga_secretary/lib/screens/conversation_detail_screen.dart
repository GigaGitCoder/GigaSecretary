import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../models/conversation.dart';
import '../services/conversation_service.dart';
import '../services/drive_service.dart';
import '../widgets/audio_progress_bar.dart';

class ConversationDetailScreen extends StatefulWidget {
  final Conversation conversation;
  final DriveService driveService;

  const ConversationDetailScreen({
    Key? key,
    required this.conversation,
    required this.driveService,
  }) : super(key: key);

  @override
  State<ConversationDetailScreen> createState() => _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen> {
  AudioPlayer? _player;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = await widget.driveService.getFileDownloadUrl(widget.conversation.fileId);
      if (url == null) {
        throw Exception('Не удалось получить URL файла');
      }

      print('Audio URL: $url'); // Для отладки

      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());

      _player = AudioPlayer();
      
      try {
        // Получаем токен авторизации
        final authHeaders = await widget.driveService.getAuthHeaders();
        if (authHeaders == null) {
          throw Exception('Не удалось получить заголовки авторизации');
        }

        // Устанавливаем источник аудио с заголовками авторизации
        await _player?.setAudioSource(
          AudioSource.uri(
            Uri.parse(url),
            headers: {
              ...authHeaders,
              'Accept': '*/*',
              'Range': 'bytes=0-',
            },
          ),
          initialPosition: Duration.zero,
        );

        // Проверяем, что аудио успешно загружено
        final duration = await _player?.duration;
        if (duration == null) {
          throw Exception('Не удалось загрузить аудио файл');
        }
      } catch (e) {
        print('Error setting URL: $e');
        throw Exception('Не удалось загрузить аудио файл. Проверьте подключение к интернету и попробуйте снова.');
      }

      _player?.positionStream.listen((position) {
        if (mounted) {
          setState(() => _position = position);
        }
      });

      _player?.durationStream.listen((duration) {
        if (mounted && duration != null) {
          setState(() => _duration = duration);
        }
      });

      _player?.playerStateStream.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state.playing);
        }
      }, onError: (error) {
        print('Player state error: $error');
        if (mounted) {
          setState(() {
            _errorMessage = 'Ошибка воспроизведения. Попробуйте перезагрузить аудио.';
          });
        }
      });

    } catch (e) {
      print('Audio player error: $e');
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D162D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2157),
        title: const Text('Просмотр записи', style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: const Color(0xFF1A2157),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      widget.conversation.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Создано: ${_formatDateTime(widget.conversation.createdAt)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: const Color(0xFF1A2157),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Аудиозапись',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoading)
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Загрузка аудио...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      )
                    else if (_errorMessage != null)
                      Center(
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
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _initAudioPlayer,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Повторить попытку'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(_position),
                                style: const TextStyle(color: Colors.white70),
                              ),
                              Text(
                                _formatDuration(_duration),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          AudioProgressBar(
                            progress: _position,
                            total: _duration,
                            onSeek: (position) {
                              _player?.seek(position);
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                  color: Colors.blue,
                                  size: 48,
                                ),
                                onPressed: () {
                                  if (_isPlaying) {
                                    _player?.pause();
                                  } else {
                                    _player?.play();
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            if (widget.conversation.summary != null) ...[
              const SizedBox(height: 8),
              Card(
                color: const Color(0xFF1A2157),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Краткое содержание',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.conversation.summary!,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (widget.conversation.responsibilities != null) ...[
              const SizedBox(height: 8),
              Card(
                color: const Color(0xFF1A2157),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Обязанности',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.conversation.responsibilities!,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (widget.conversation.transcript != null) ...[
              const SizedBox(height: 8),
              Card(
                color: const Color(0xFF1A2157),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Расшифровка',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.conversation.transcript!,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
