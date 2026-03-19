import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:sangeet/utils/platform_utils.dart';

/// Represents an audio output device
class AudioOutputDevice {
  final String id;
  final String name;
  final AudioOutputDeviceType type;
  final bool isConnected;
  final bool isActive;

  const AudioOutputDevice({
    required this.id,
    required this.name,
    required this.type,
    this.isConnected = true,
    this.isActive = false,
  });

  AudioOutputDevice copyWith({
    String? id,
    String? name,
    AudioOutputDeviceType? type,
    bool? isConnected,
    bool? isActive,
  }) {
    return AudioOutputDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isConnected: isConnected ?? this.isConnected,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioOutputDevice && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

enum AudioOutputDeviceType {
  phone,
  bluetooth,
  wiredHeadphones,
  speaker,
  usbAudio,
  unknown,
}

/// Service to manage audio output device selection
class AudioDeviceService {
  static final AudioDeviceService _instance = AudioDeviceService._internal();
  factory AudioDeviceService() => _instance;
  AudioDeviceService._internal();

  audio_session.AudioSession? _session;
  bool _initialized = false;

  final ValueNotifier<List<AudioOutputDevice>> devicesNotifier = ValueNotifier([]);
  final ValueNotifier<AudioOutputDevice?> activeDeviceNotifier = ValueNotifier(null);

  StreamSubscription<dynamic>? _deviceChangeSubscription;
  StreamSubscription<dynamic>? _interruptionSubscription;

  /// Initialize the audio device service
  Future<void> initialize() async {
    if (_initialized) return;

    // On desktop, audio_session is not supported - provide default device
    if (PlatformUtils.isDesktop) {
      final defaultDevice = const AudioOutputDevice(
        id: 'system_audio',
        name: 'System Audio',
        type: AudioOutputDeviceType.speaker,
        isConnected: true,
        isActive: true,
      );
      devicesNotifier.value = [defaultDevice];
      activeDeviceNotifier.value = defaultDevice;
      _initialized = true;
      debugPrint('AudioDeviceService: Desktop platform — using system audio');
      return;
    }

    try {
      _session = await audio_session.AudioSession.instance;

      // Configure for music playback - this helps with device switching
      await _session!.configure(const audio_session.AudioSessionConfiguration(
        avAudioSessionCategory: audio_session.AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: audio_session.AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: audio_session.AVAudioSessionMode.defaultMode,
        androidAudioAttributes: audio_session.AndroidAudioAttributes(
          contentType: audio_session.AndroidAudioContentType.music,
          usage: audio_session.AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: audio_session.AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));

      // Listen for device changes
      _setupDeviceChangeListener();

      // Listen for audio interruptions (helps with device switching)
      _setupInterruptionListener();

      // Get initial devices
      await refreshDevices();

      _initialized = true;
    } catch (e) {
      debugPrint('AudioDeviceService: Failed to initialize: $e');
    }
  }

  void _setupDeviceChangeListener() {
    _deviceChangeSubscription = _session?.devicesChangedEventStream.listen((_) {
      debugPrint('AudioDeviceService: Devices changed, refreshing...');
      refreshDevices();
    });
  }

  void _setupInterruptionListener() {
    // Handle audio interruptions (like when Bluetooth connects/disconnects)
    _interruptionSubscription = _session?.interruptionEventStream.listen((event) {
      debugPrint('AudioDeviceService: Interruption event: ${event.begin}, ${event.type}');
      // Just refresh devices, don't stop playback
      refreshDevices();
    });
  }

  /// Refresh the list of available audio devices
  Future<void> refreshDevices() async {
    if (_session == null) {
      await initialize();
      return;
    }

    try {
      final devices = await _session!.getDevices();

      final audioDevices = <AudioOutputDevice>[];
      final seenDeviceNames = <String>{}; // Track by NAME to avoid duplicates

      // Determine which device type should be active (priority: BT > Wired > Speaker)
      AudioOutputDeviceType? priorityType;
      String? priorityDeviceName;

      for (final device in devices) {
        final deviceType = _mapDeviceType(device.type);

        // Skip earpiece
        if (device.type == audio_session.AudioDeviceType.builtInEarpiece) {
          continue;
        }

        // Skip unknown devices
        if (deviceType == AudioOutputDeviceType.unknown) {
          continue;
        }

        // Track priority for active device detection
        if (deviceType == AudioOutputDeviceType.bluetooth) {
          priorityType = AudioOutputDeviceType.bluetooth;
          priorityDeviceName = device.name;
        } else if (deviceType == AudioOutputDeviceType.wiredHeadphones &&
                   priorityType != AudioOutputDeviceType.bluetooth) {
          priorityType = AudioOutputDeviceType.wiredHeadphones;
          priorityDeviceName = device.name;
        } else if (deviceType == AudioOutputDeviceType.usbAudio &&
                   priorityType == null) {
          priorityType = AudioOutputDeviceType.usbAudio;
          priorityDeviceName = device.name;
        }
      }

      // Now build the unique device list
      for (final device in devices) {
        final deviceType = _mapDeviceType(device.type);

        // Skip earpiece and unknown
        if (device.type == audio_session.AudioDeviceType.builtInEarpiece ||
            deviceType == AudioOutputDeviceType.unknown) {
          continue;
        }

        // Use device name as unique key (prevents BT duplicates from A2DP/SCO/LE)
        final uniqueKey = '${device.name}_${deviceType.name}';
        if (seenDeviceNames.contains(uniqueKey)) {
          continue;
        }
        seenDeviceNames.add(uniqueKey);

        // Determine if this device is active
        final isActive = (priorityType != null && deviceType == priorityType && device.name == priorityDeviceName) ||
                         (priorityType == null && device.type == audio_session.AudioDeviceType.builtInSpeaker);

        audioDevices.add(AudioOutputDevice(
          id: device.id,
          name: device.name,
          type: deviceType,
          isConnected: true,
          isActive: isActive,
        ));
      }

      // Ensure phone speaker is in the list if no external devices
      final hasPhoneSpeaker = audioDevices.any((d) =>
          d.type == AudioOutputDeviceType.phone ||
          d.name.toLowerCase().contains('speaker'));

      if (!hasPhoneSpeaker || audioDevices.isEmpty) {
        final isActive = priorityType == null;
        audioDevices.insert(0, AudioOutputDevice(
          id: 'phone_speaker',
          name: 'Phone Speaker',
          type: AudioOutputDeviceType.phone,
          isConnected: true,
          isActive: isActive,
        ));
      }

      // Find the active device
      final activeDevice = audioDevices.firstWhere(
        (d) => d.isActive,
        orElse: () => audioDevices.first,
      );

      devicesNotifier.value = audioDevices;
      activeDeviceNotifier.value = activeDevice;

      debugPrint('AudioDeviceService: Found ${audioDevices.length} devices, active: ${activeDevice.name}');
    } catch (e) {
      debugPrint('AudioDeviceService: Failed to refresh devices: $e');
      final defaultDevice = const AudioOutputDevice(
        id: 'phone_speaker',
        name: 'Phone Speaker',
        type: AudioOutputDeviceType.phone,
        isConnected: true,
        isActive: true,
      );
      devicesNotifier.value = [defaultDevice];
      activeDeviceNotifier.value = defaultDevice;
    }
  }

  /// Select a specific audio output device
  Future<bool> selectDevice(AudioOutputDevice device) async {
    try {
      // Update the active device in our state
      final updatedDevices = devicesNotifier.value.map((d) {
        return d.copyWith(isActive: d.id == device.id);
      }).toList();

      devicesNotifier.value = updatedDevices;
      activeDeviceNotifier.value = device.copyWith(isActive: true);

      debugPrint('AudioDeviceService: Selected device: ${device.name}');
      return true;
    } catch (e) {
      debugPrint('AudioDeviceService: Failed to select device: $e');
      return false;
    }
  }

  AudioOutputDeviceType _mapDeviceType(audio_session.AudioDeviceType type) {
    switch (type) {
      case audio_session.AudioDeviceType.builtInSpeaker:
        return AudioOutputDeviceType.phone;
      case audio_session.AudioDeviceType.builtInEarpiece:
        return AudioOutputDeviceType.phone;
      case audio_session.AudioDeviceType.wiredHeadset:
      case audio_session.AudioDeviceType.wiredHeadphones:
        return AudioOutputDeviceType.wiredHeadphones;
      case audio_session.AudioDeviceType.bluetoothA2dp:
      case audio_session.AudioDeviceType.bluetoothSco:
      case audio_session.AudioDeviceType.bluetoothLe:
        return AudioOutputDeviceType.bluetooth;
      default:
        final typeName = type.toString().toLowerCase();
        if (typeName.contains('usb')) {
          return AudioOutputDeviceType.usbAudio;
        }
        return AudioOutputDeviceType.unknown;
    }
  }

  /// Get current list of available devices
  List<AudioOutputDevice> get devices => devicesNotifier.value;

  /// Get currently active device
  AudioOutputDevice? get activeDevice => activeDeviceNotifier.value;

  /// Check if Bluetooth audio is currently active
  bool get isBluetoothActive {
    final active = activeDevice;
    return active?.type == AudioOutputDeviceType.bluetooth;
  }

  /// Check if wired headphones are connected
  bool get isWiredHeadphonesActive {
    final active = activeDevice;
    return active?.type == AudioOutputDeviceType.wiredHeadphones;
  }

  /// Dispose resources
  void dispose() {
    _deviceChangeSubscription?.cancel();
    _interruptionSubscription?.cancel();
  }
}
