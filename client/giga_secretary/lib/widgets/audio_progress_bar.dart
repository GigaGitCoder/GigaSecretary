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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) {
            _isDragging = true;
            _dragValue = widget.progress.inMilliseconds.toDouble();
          },
          onHorizontalDragUpdate: (details) {
            final width = constraints.maxWidth;
            final dx = details.localPosition.dx;
            final percent = dx / width;
            
            _dragValue = (widget.total.inMilliseconds.toDouble() * percent)
                .clamp(0.0, widget.total.inMilliseconds.toDouble());
            
            setState(() {});
          },
          onHorizontalDragEnd: (details) {
            widget.onSeek(Duration(milliseconds: _dragValue.toInt()));
            _isDragging = false;
          },
          onTapDown: (details) {
            final width = constraints.maxWidth;
            final dx = details.localPosition.dx;
            final percent = dx / width;
            
            final position = Duration(
              milliseconds: (widget.total.inMilliseconds * percent).toInt(),
            );
            widget.onSeek(position);
          },
          child: Stack(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: _isDragging
                    ? _dragValue / widget.total.inMilliseconds
                    : widget.progress.inMilliseconds / widget.total.inMilliseconds,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Positioned(
                left: _isDragging
                    ? (_dragValue / widget.total.inMilliseconds) * constraints.maxWidth - 6
                    : (widget.progress.inMilliseconds / widget.total.inMilliseconds) * constraints.maxWidth - 6,
                top: -4,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
} 