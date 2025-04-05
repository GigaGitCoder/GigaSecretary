import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

class ViewRecordingScreen extends StatefulWidget {
  const ViewRecordingScreen({super.key});

  @override
  _ViewRecordingScreenState createState() => _ViewRecordingScreenState();
}

class _ViewRecordingScreenState extends State<ViewRecordingScreen> {
  late AudioPlayer _player;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _player = AudioPlayer();
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.music());
    await _player.setUrl('https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3');
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0D162D),
      appBar: AppBar(
        backgroundColor: Color(0xFF1A2157),
        title: const Text('Просмотр беседы', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildAudioPlayer(),

            const SizedBox(height: 20),

            _buildCard('Краткий пересказ', 'Пересказ беседы будет здесь...'),
            const SizedBox(height: 16),
            _buildCard('Обязанности', 'Список обязанностей...'),
            const SizedBox(height: 16),
            _buildCard('Текст беседы', 'Полный текст беседы...'),

            const Spacer(),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildButton(Icons.arrow_back, 'Назад', () => Navigator.pop(context)),
                _buildButton(Icons.edit, 'Роли', () {
                  Navigator.pushNamed(context, '/roles');
                }),
                _buildButton(Icons.delete, 'Удалить', () {
                  // удалить
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPlayer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF1A2157),
        borderRadius: BorderRadius.circular(20),
      ),
      child: StreamBuilder<PlayerState>(
        stream: _player.playerStateStream,
        builder: (context, snapshot) {
          final playing = snapshot.data?.playing ?? false;
          return Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      size: 40,
                      color: Color(0xFF3B47AE),
                    ),
                    onPressed: () {
                      if (playing) {
                        _player.pause();
                      } else {
                        _player.play();
                      }
                    },
                  ),
                  Expanded(
                    child: StreamBuilder<Duration>(
                      stream: _player.positionStream,
                      builder: (context, snapshot) {
                        final position = snapshot.data ?? Duration.zero;
                        final total = _player.duration ?? Duration(seconds: 1);
                        return Slider(
                          value: position.inMilliseconds.toDouble().clamp(0, total.inMilliseconds.toDouble()),
                          max: total.inMilliseconds.toDouble(),
                          onChanged: (value) {
                            _player.seek(Duration(milliseconds: value.toInt()));
                          },
                          activeColor: Color(0xFF3B47AE),
                          inactiveColor: Colors.white24,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A2157),
        borderRadius: BorderRadius.circular(16),
      ),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18, color: Colors.white70, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildButton(IconData icon, String label, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF3B47AE),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
