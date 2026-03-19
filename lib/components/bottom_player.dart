import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sangeet/models/song.dart';
import 'package:sangeet/services/audio_player_service.dart';
import 'package:sangeet/services/audio_device_service.dart';
import 'package:sangeet/components/device_selector_sheet.dart';
import '../screens/body.dart';

/// Bottom player widget with optional custom onTap callback
class BottomPlayer extends StatelessWidget {
  final Color backgroundColor;
  final VoidCallback? onTap;

  const BottomPlayer({
    Key? key,
    required this.backgroundColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final audio = AudioPlayerService();
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;
    final horizontalPad = isWide ? 20.0 : 12.0;
    final playerHeight = isWide ? 72.0 : 64.0;

    return AnimatedBuilder(
      animation: audio.queue,
      builder: (context, _) {
        final Song? song = audio.currentSong;
        if (song == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            if (onTap != null) {
              onTap!();
            } else {
              BodyState.instance?.openPlayerForCurrentSong();
            }
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPad),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      height: playerHeight,
                      padding: EdgeInsets.symmetric(horizontal: isWide ? 16 : 12),
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
                          // Animated cover art change
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            child: ClipRRect(
                              key: ValueKey('mini_art_${song.id}'),
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
                          ),
                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Text(
                                    song.title,
                                    key: ValueKey('mini_title_${song.id}'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Text(
                                    song.artist,
                                    key: ValueKey('mini_artist_${song.id}'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.65),
                                      fontSize: 12,
                                    ),
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
                              return _MiniPlayPauseButton(
                                isPlaying: playing,
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

/// Mini player animated play/pause button.
class _MiniPlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onPressed;

  const _MiniPlayPauseButton({required this.isPlaying, required this.onPressed});

  @override
  State<_MiniPlayPauseButton> createState() => _MiniPlayPauseButtonState();
}

class _MiniPlayPauseButtonState extends State<_MiniPlayPauseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: widget.isPlaying ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(_MiniPlayPauseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      widget.isPlaying ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: AnimatedIcon(
        icon: AnimatedIcons.play_pause,
        progress: CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        size: 36,
        color: Colors.white,
      ),
      onPressed: widget.onPressed,
    );
  }
}
