import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';

class ProgressBar extends StatelessWidget {
  final Stream<Duration> positionStream;
  final Stream<Duration?> durationStream;
  final Color accentColor;
  final void Function(Duration) onSeek;

  const ProgressBar({
    super.key,
    required this.positionStream,
    required this.durationStream,
    required this.accentColor,
    required this.onSeek,
  });

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: durationStream,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;

        return StreamBuilder<Duration>(
          stream: positionStream,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;

            final max = duration.inMilliseconds.toDouble();
            final value = position.inMilliseconds
                .clamp(0, max)
                .toDouble();

            return Column(
              children: [
                Slider(
                  value: max == 0 ? 0 : value,
                  min: 0,
                  max: max == 0 ? 1 : max,
                  onChanged: (v) {
                    onSeek(Duration(milliseconds: v.toInt()));
                  },
                  activeColor: kPrimaryColor,
                  inactiveColor: Colors.white24,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _format(position),
                      style: TextStyle(color: accentColor),
                    ),
                    Text(
                      _format(duration),
                      style: TextStyle(color: accentColor),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}
