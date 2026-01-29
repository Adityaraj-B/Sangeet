import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/audio_device_service.dart';

/// Shows a bottom sheet for selecting audio output device
/// Similar to Spotify's "Connect to a device" feature
class DeviceSelectorSheet extends StatefulWidget {
  const DeviceSelectorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const DeviceSelectorSheet(),
    );
  }

  @override
  State<DeviceSelectorSheet> createState() => _DeviceSelectorSheetState();
}

class _DeviceSelectorSheetState extends State<DeviceSelectorSheet> {
  final AudioDeviceService _deviceService = AudioDeviceService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshDevices();
  }

  Future<void> _refreshDevices() async {
    setState(() => _isLoading = true);
    await _deviceService.initialize();
    await _deviceService.refreshDevices();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 30),
            child: child,
          ),
        );
      },
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.speaker_group_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connect to a device',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Select where to play',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Refresh button
                      IconButton(
                        onPressed: _refreshDevices,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white60,
                                ),
                              )
                            : const Icon(
                                Icons.refresh_rounded,
                                color: Colors.white60,
                              ),
                      ),
                    ],
                  ),
                ),

                Divider(
                  color: Colors.white.withValues(alpha: 0.1),
                  height: 1,
                ),

                // Devices list
                Flexible(
                  child: ValueListenableBuilder<List<AudioOutputDevice>>(
                    valueListenable: _deviceService.devicesNotifier,
                    builder: (context, devices, _) {
                      if (_isLoading && devices.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(
                              color: Colors.white60,
                            ),
                          ),
                        );
                      }

                      if (devices.isEmpty) {
                        return _buildEmptyState();
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          return _DeviceTile(
                            device: device,
                            onTap: () => _selectDevice(device),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Info text
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Connect Bluetooth devices or speakers in your phone settings to see them here.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.speaker_rounded,
            size: 48,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No devices found',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect a Bluetooth speaker or headphones',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _selectDevice(AudioOutputDevice device) async {
    // Actually select the device
    final success = await _deviceService.selectDevice(device);

    if (!mounted) return;

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(_getDeviceIcon(device.type), color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(success
                  ? 'Playing on ${device.name}'
                  : 'Connected to ${device.name}'),
            ),
          ],
        ),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }

  IconData _getDeviceIcon(AudioOutputDeviceType type) {
    switch (type) {
      case AudioOutputDeviceType.bluetooth:
        return Icons.bluetooth_audio_rounded;
      case AudioOutputDeviceType.wiredHeadphones:
        return Icons.headphones_rounded;
      case AudioOutputDeviceType.speaker:
        return Icons.speaker_rounded;
      case AudioOutputDeviceType.phone:
        return Icons.phone_android_rounded;
      case AudioOutputDeviceType.usbAudio:
        return Icons.usb_rounded;
      case AudioOutputDeviceType.unknown:
        return Icons.volume_up_rounded;
    }
  }
}

class _DeviceTile extends StatelessWidget {
  final AudioOutputDevice device;
  final VoidCallback onTap;

  const _DeviceTile({
    required this.device,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withValues(alpha: 0.1),
        highlightColor: Colors.white.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              // Device icon with background
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: device.isActive
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIcon(),
                  color: device.isActive ? Colors.greenAccent : Colors.white70,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Device info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: TextStyle(
                        color: device.isActive ? Colors.greenAccent : Colors.white,
                        fontSize: 16,
                        fontWeight: device.isActive ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getTypeLabel(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // Active indicator
              if (device.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Playing',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (device.type) {
      case AudioOutputDeviceType.bluetooth:
        return Icons.bluetooth_audio_rounded;
      case AudioOutputDeviceType.wiredHeadphones:
        return Icons.headphones_rounded;
      case AudioOutputDeviceType.speaker:
        return Icons.speaker_rounded;
      case AudioOutputDeviceType.phone:
        return Icons.phone_android_rounded;
      case AudioOutputDeviceType.usbAudio:
        return Icons.usb_rounded;
      case AudioOutputDeviceType.unknown:
        return Icons.volume_up_rounded;
    }
  }

  String _getTypeLabel() {
    switch (device.type) {
      case AudioOutputDeviceType.bluetooth:
        return 'Bluetooth';
      case AudioOutputDeviceType.wiredHeadphones:
        return 'Wired headphones';
      case AudioOutputDeviceType.speaker:
        return 'External speaker';
      case AudioOutputDeviceType.phone:
        return 'This device';
      case AudioOutputDeviceType.usbAudio:
        return 'USB audio';
      case AudioOutputDeviceType.unknown:
        return 'Audio device';
    }
  }
}
