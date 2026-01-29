import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sangeet/models/song.dart';
import 'package:sangeet/services/audio_player_service.dart';
import 'package:sangeet/services/audio_device_service.dart';
import 'package:sangeet/components/device_selector_sheet.dart';
import '../screens/body.dart';

class BottomPlayer extends StatelessWidget {
  final Color backgroundColor;

  const BottomPlayer({
    super.key,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final audio = AudioPlayerService();

    return AnimatedBuilder(
      animation: audio.queue,
      builder: (context, _) {
        final Song? song = audio.currentSong;
        if (song == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            // Delegate to Body to open the player (prevents duplicate routes)
            BodyState.instance?.openPlayerForCurrentSong();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      height: 64,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 0.6,
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              song.coverUrl,
                              height: 44,
                              width: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 44,
                                width: 44,
                                color: Colors.black.withValues(alpha: 0.2),
                                child: const Icon(
                                  Icons.music_note,
                                  color: Colors.white24,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.65),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          IconButton(
                            icon: const Icon(Icons.skip_previous_rounded),
                            color: Colors.white,
                            onPressed: audio.playPrevious,
                          ),

                          StreamBuilder<bool>(
                            stream: audio.playingStream,
                            initialData: audio.isPlaying,
                            builder: (context, snapshot) {
                              final playing = snapshot.data ?? false;
                              return IconButton(
                                icon: Icon(
                                  playing
                                      ? Icons.pause_circle_filled_rounded
                                      : Icons.play_circle_filled_rounded,
                                  size: 36,
                                  color: Colors.white,
                                ),
                                onPressed: audio.togglePlayPause,
                              );
                            },
                          ),

                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded),
                            color: Colors.white,
                            onPressed: audio.playNext,
                          ),

                          // Device selector button
                          ValueListenableBuilder<AudioOutputDevice?>(
                            valueListenable: AudioDeviceService().activeDeviceNotifier,
                            builder: (context, activeDevice, _) {
                              final isExternalDevice = activeDevice != null &&
                                  activeDevice.type != AudioOutputDeviceType.phone;
                              return IconButton(
                                icon: Icon(
                                  _getDeviceIcon(activeDevice?.type),
                                  size: 20,
                                  color: isExternalDevice
                                      ? Colors.greenAccent
                                      : Colors.white.withValues(alpha: 0.7),
                                ),
                                onPressed: () => DeviceSelectorSheet.show(context),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getDeviceIcon(AudioOutputDeviceType? type) {
    switch (type) {
      case AudioOutputDeviceType.bluetooth:
        return Icons.bluetooth_audio_rounded;
      case AudioOutputDeviceType.wiredHeadphones:
        return Icons.headphones_rounded;
      case AudioOutputDeviceType.speaker:
        return Icons.speaker_rounded;
      case AudioOutputDeviceType.usbAudio:
        return Icons.usb_rounded;
      case AudioOutputDeviceType.phone:
      case AudioOutputDeviceType.unknown:
      case null:
        return Icons.speaker_group_outlined;
    }
  }
}
