import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../models/conversation.dart';
import '../services/conversation_service.dart';
import '../services/drive_service.dart';
import '../widgets/audio_progress_bar.dart';
import 'package:video_player/video_player.dart';

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
  VideoPlayerController? _controller;
  bool _isVideoPlaying = false;
  bool _isSeeking = false;
  bool _isAudioSeeking = false;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
    if (widget.conversation.isVideo) {
      _initVideoPlayer();
    }
  }

  Future<void> _initAudioPlayer() async {
    if (widget.conversation.isVideo) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = await widget.driveService.getFileDownloadUrl(widget.conversation.fileId);
      if (url == null) {
        throw Exception('Не удалось получить URL файла');
      }

      print('Audio URL: $url');

      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());

      _player = AudioPlayer();
      
      try {
        final authHeaders = await widget.driveService.getAuthHeaders();
        if (authHeaders == null) {
          throw Exception('Не удалось получить заголовки авторизации');
        }

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

        // Получаем и проверяем длительность
        final duration = await _player?.duration;
        print('Initial duration: ${duration?.inSeconds} seconds');
        
        if (duration == null || duration == Duration.zero) {
          throw Exception('Не удалось определить длительность аудио');
        }

        setState(() {
          _duration = duration;
        });
      } catch (e) {
        print('Error setting URL: $e');
        throw Exception('Не удалось загрузить аудио файл. Проверьте подключение к интернету и попробуйте снова.');
      }

      _player?.positionStream.listen((position) {
        if (mounted && !_isAudioSeeking) {
          setState(() {
            _position = position;
          });
          print('Current position: ${position.inSeconds} seconds');
        }
      });

      _player?.durationStream.listen((duration) {
        if (mounted && duration != null) {
          setState(() {
            _duration = duration;
          });
          print('Updated duration: ${duration.inSeconds} seconds');
        }
      });

      _player?.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
            if (state.processingState == ProcessingState.completed) {
              _isPlaying = false;
              _position = Duration.zero;
            }
          });
        }
      }, onError: (error) {
        print('Player state error: $error');
        if (mounted) {
          setState(() {
            _errorMessage = 'Ошибка воспроизведения. Попробуйте перезагрузить аудио.';
          });
        }
      });

      setState(() => _isLoading = false);
    } catch (e) {
      print('Audio player error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _initVideoPlayer() async {
    if (!widget.conversation.isVideo) return;

    try {
      final authHeaders = await widget.driveService.getAuthHeaders();
      if (authHeaders == null) {
        throw Exception('Не удалось получить заголовки авторизации');
      }

      _controller = VideoPlayerController.network(
        widget.conversation.videoUrl,
        httpHeaders: {
          ...authHeaders,
          'Accept': '*/*',
          'Range': 'bytes=0-',
        },
      );
      
      await _controller!.initialize();
      _controller!.addListener(_videoListener);
      
      setState(() {});
    } catch (e) {
      print('Error initializing video player: $e');
      setState(() {
        _errorMessage = 'Не удалось загрузить видео: ${e.toString()}';
      });
    }
  }

  void _videoListener() {
    if (!mounted || _controller == null) return;
    
    setState(() {
      _isVideoPlaying = _controller!.value.isPlaying;
      if (!_isSeeking) {
        _position = _controller!.value.position;
      }
      _isPlaying = _controller!.value.isPlaying;
    });
  }

  void _playPause() async {
    if (widget.conversation.isVideo) {
      if (_controller == null) return;
      
      if (_controller!.value.isPlaying) {
        await _controller!.pause();
      } else {
        await _controller!.play();
      }
      setState(() {
        _isVideoPlaying = !_controller!.value.isPlaying;
        _isPlaying = _controller!.value.isPlaying;
      });
      return;
    }

    try {
      if (_isPlaying) {
        await _player?.pause();
      } else {
        // Если мы в конце трека, начинаем сначала
        if (_position >= _duration) {
          await _player?.seek(Duration.zero);
          setState(() {
            _position = Duration.zero;
          });
        }
        await _player?.play();
      }
      setState(() {
        _isPlaying = !_isPlaying;
      });
    } catch (e) {
      print('Error playing/pausing: $e');
    }
  }

  Future<void> _seekAudio(Duration position) async {
    if (_player == null) return;
    if (_duration == Duration.zero) return;

    try {
      // Останавливаем воспроизведение на время перемотки
      final wasPlaying = _isPlaying;
      await _player?.pause();

      // Проверяем, что позиция не выходит за пределы
      final validPosition = position.inMilliseconds.clamp(0, _duration.inMilliseconds);
      final targetPosition = Duration(milliseconds: validPosition);

      print('Seeking to position: ${targetPosition.inSeconds}/${_duration.inSeconds} seconds');

      // Делаем перемотку
      await _player?.seek(targetPosition);

      // Ждем немного, чтобы перемотка успела выполниться
      await Future.delayed(const Duration(milliseconds: 50));

      // Возобновляем воспроизведение, если оно было активно
      if (wasPlaying) {
        await _player?.play();
      }

      setState(() {
        _position = targetPosition;
      });
    } catch (e) {
      print('Error seeking: $e');
      // В случае ошибки пытаемся восстановить плеер
      await _player?.seek(Duration.zero);
      setState(() {
        _position = Duration.zero;
        _isPlaying = false;
      });
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    if (widget.conversation.isVideo && _controller != null) {
      _controller!.removeListener(_videoListener);
      _controller!.dispose();
    }
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
    final localTime = dateTime.toLocal();
    return '${localTime.day.toString().padLeft(2, '0')}.${localTime.month.toString().padLeft(2, '0')}.${localTime.year} ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D162D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2157),
        title: Text(
          widget.conversation.title,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: const Color(0xFF1A2157),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Информация',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('Название', widget.conversation.title),
                      const SizedBox(height: 8),
                      _buildInfoRow('Дата создания', _formatDateTime(widget.conversation.createdAt)),
                      const SizedBox(height: 8),
                      _buildInfoRow('Размер', widget.conversation.formattedSize),
                      const SizedBox(height: 8),
                      _buildInfoRow('Тип', widget.conversation.isVideo ? 'Видео' : 'Аудио'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: const Color(0xFF1A2157),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Плеер',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (widget.conversation.isVideo && _controller != null)
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: VideoPlayer(_controller!),
                        )
                      else if (widget.conversation.isVideo)
                        const Center(
                          child: CircularProgressIndicator(),
                        ),
                      const SizedBox(height: 16),
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(),
                        )
                      else if (_errorMessage != null)
                        Center(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        Column(
                          children: [
                            if (widget.conversation.isVideo && _controller != null)
                              Column(
                                children: [
                                  Slider(
                                    value: _position.inMilliseconds.toDouble(),
                                    min: 0,
                                    max: _controller!.value.duration.inMilliseconds.toDouble(),
                                    onChanged: (double newValue) {
                                      setState(() {
                                        _isSeeking = true;
                                        _position = Duration(milliseconds: newValue.toInt());
                                      });
                                      _controller!.seekTo(_position);
                                    },
                                    onChangeEnd: (double newValue) async {
                                      setState(() {
                                        _isSeeking = false;
                                      });
                                      if (_isVideoPlaying) {
                                        await _controller!.play();
                                      }
                                    },
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatDuration(_position),
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                        Text(
                                          _formatDuration(_controller!.value.duration),
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else if (!widget.conversation.isVideo)
                              AudioProgressBar(
                                progress: _position,
                                total: _duration,
                                onSeek: _seekAudio,
                              ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    widget.conversation.isVideo
                                        ? (_controller?.value.isPlaying ?? false
                                            ? Icons.pause
                                            : Icons.play_arrow)
                                        : (_isPlaying
                                            ? Icons.pause_circle_filled
                                            : Icons.play_circle_filled),
                                    color: Colors.white,
                                    size: widget.conversation.isVideo ? 24 : 48,
                                  ),
                                  onPressed: _playPause,
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }
}
