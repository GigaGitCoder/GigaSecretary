import 'package:flutter/material.dart';

class AudioProgressBar extends StatefulWidget {
  final Duration progress;
  final Duration total;
  final Function(Duration) onSeek;

  const AudioProgressBar({
    Key? key,
    required this.progress,
    required this.total,
    required this.onSeek,
  }) : super(key: key);

  @override
  State<AudioProgressBar> createState() => _AudioProgressBarState();
}

class _AudioProgressBarState extends State<AudioProgressBar> {
  bool _isDragging = false;
  late double _dragValue;

  @override
  void initState() {
    super.initState();
    _dragValue = widget.progress.inMilliseconds.toDouble();
  }

  @override
  void didUpdateWidget(AudioProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging) {
      _dragValue = widget.progress.inMilliseconds.toDouble();
    }
  }

  double _validateValue(double value) {
    if (widget.total.inMilliseconds == 0) return 0;
    return value.clamp(0, widget.total.inMilliseconds.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.total == Duration.zero) {
      return const SizedBox.shrink();
    }

    final currentValue = _isDragging ? _dragValue : widget.progress.inMilliseconds.toDouble();
    final validatedValue = _validateValue(currentValue);
    final maxDuration = widget.total.inMilliseconds.toDouble();

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white30,
            thumbColor: Colors.white,
            overlayColor: Colors.white.withOpacity(0.1),
            trackHeight: 4.0,
          ),
          child: Slider(
            value: validatedValue,
            min: 0,
            max: maxDuration,
            onChangeStart: (_) {
              setState(() {
                _isDragging = true;
                _dragValue = validatedValue;
              });
            },
            onChanged: (value) {
              setState(() {
                _dragValue = _validateValue(value);
              });
            },
            onChangeEnd: (value) {
              final targetPosition = Duration(milliseconds: _validateValue(value).toInt());
              widget.onSeek(targetPosition);
              setState(() {
                _isDragging = false;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(Duration(milliseconds: validatedValue.toInt())),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                _formatDuration(widget.total),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
} 