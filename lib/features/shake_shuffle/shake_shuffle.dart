import 'dart:async';
import 'dart:math';

import 'package:classipod/core/providers/filtered_audio_files_provider.dart';
import 'package:classipod/core/providers/shared_preferences_with_cache_provider.dart';
import 'package:classipod/core/services/audio_player_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Setting: shake the device to start a random playback of all songs.
final shakeToShuffleProvider = NotifierProvider<ShakeToShuffleNotifier, bool>(
  ShakeToShuffleNotifier.new,
);

class ShakeToShuffleNotifier extends Notifier<bool> {
  static const _key = 'shakeToShuffle';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesWithCacheProvider).value;
    return prefs?.getBool(_key) ?? false;
  }

  Future<void> toggle() async {
    final enabled = !state;
    state = enabled;
    final prefs = ref.read(sharedPreferencesWithCacheProvider).value;
    await prefs?.setBool(_key, enabled);
  }
}

final shakeSoundServiceProvider = Provider<ShakeSoundService>((ref) {
  final service = ShakeSoundService(
    AudioPlayer(
      handleAudioSessionActivation: false,
      handleInterruptions: false,
      androidApplyAudioAttributes: false,
    ),
  );
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

class ShakeSoundService {
  ShakeSoundService(this._player);

  /// Change the extension here if your file is not an mp3.
  static const asset = 'assets/sounds/shake_jingle.mp3';

  final AudioPlayer _player;

  /// Plays the jingle and completes when it has finished (or failed).
  Future<void> play() async {
    try {
      await _player.setAsset(asset);
      await _player.play().timeout(const Duration(seconds: 8));
    } catch (error) {
      debugPrint('Shake sound failed: ${error.runtimeType}');
    } finally {
      try {
        await _player.stop();
      } catch (_) {}
    }
  }

  Future<void> dispose() => _player.dispose();
}

class _ShakeDetector {
  _ShakeDetector(this.onShake);

  final VoidCallback onShake;

  /// Tune these to change how hard and how many times you have to shake.
  static const double threshold = 15; // m/s², gravity excluded
  static const int requiredShakes = 3;
  static const Duration window = Duration(milliseconds: 1200);
  static const Duration minGap = Duration(milliseconds: 150);
  static const Duration cooldown = Duration(seconds: 4);

  final List<DateTime> _shakes = [];
  DateTime _lastTrigger = DateTime.fromMillisecondsSinceEpoch(0);

  void add(UserAccelerometerEvent event) {
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    if (magnitude < threshold) return;
    final now = DateTime.now();
    if (now.difference(_lastTrigger) < cooldown) return;
    if (_shakes.isNotEmpty && now.difference(_shakes.last) < minGap) return;
    _shakes
      ..add(now)
      ..removeWhere((time) => now.difference(time) > window);
    if (_shakes.length >= requiredShakes) {
      _shakes.clear();
      _lastTrigger = now;
      onShake();
    }
  }
}

bool get _isMobile =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Listens to the accelerometer while "Shake to Shuffle" is enabled.
final shakeShuffleProvider = Provider<void>((ref) {
  if (!_isMobile || !ref.watch(shakeToShuffleProvider)) return;
  var busy = false;

  Future<void> onShake() async {
    if (busy) return;
    busy = true;
    try {
      final library = ref.read(filteredAudioFilesProvider).value;
      if (library == null || library.isEmpty) return;
      final player = ref.read(audioPlayerServiceProvider.notifier);
      await player.pause();
      if (!ref.mounted) return;
      await ref.read(shakeSoundServiceProvider).play();
      if (!ref.mounted) return;
      await player.shuffleAllSongs();
    } catch (error) {
      debugPrint('Shake shuffle failed: ${error.runtimeType}');
    } finally {
      busy = false;
    }
  }

  final detector = _ShakeDetector(() => unawaited(onShake()));
  final subscription =
      userAccelerometerEventStream(
        samplingPeriod: SensorInterval.uiInterval,
      ).listen(detector.add, onError: (Object _) {});
  ref.onDispose(subscription.cancel);
});
