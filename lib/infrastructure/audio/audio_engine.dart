import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

/// Playback abstraction for the rendered session timeline. Kept minimal on
/// purpose: load one stream, play it, read the clock. Everything else in the
/// app derives from [position].
abstract class AudioEngine {
  Future<void> init();

  /// Loads a rendered session (WAV bytes). Replaces any previous load.
  Future<void> loadSession(Uint8List wavBytes);

  Future<void> play();
  Future<void> stop();

  /// Current playback position of the loaded stream. The Master Timeline.
  Duration get position;

  bool get isPlaying;

  Future<void> dispose();
}

class SoloudAudioEngine implements AudioEngine {
  final SoLoud _soloud = SoLoud.instance;
  AudioSource? _source;
  SoundHandle? _handle;
  int _loadCounter = 0;

  @override
  Future<void> init() async {
    if (!_soloud.isInitialized) {
      await _soloud.init();
    }
  }

  @override
  Future<void> loadSession(Uint8List wavBytes) async {
    await stop();
    final old = _source;
    // Unique virtual path per load: SoLoud caches loadMem buffers by name.
    _source =
        await _soloud.loadMem('session_${_loadCounter++}.wav', wavBytes);
    if (old != null) {
      await _soloud.disposeSource(old);
    }
  }

  @override
  Future<void> play() async {
    final source = _source;
    if (source == null) {
      throw StateError('No session loaded');
    }
    await stop();
    _handle = _soloud.play(source);
  }

  @override
  Future<void> stop() async {
    final h = _handle;
    _handle = null;
    if (h != null && _soloud.getIsValidVoiceHandle(h)) {
      await _soloud.stop(h);
    }
  }

  @override
  Duration get position {
    final h = _handle;
    if (h == null || !_soloud.getIsValidVoiceHandle(h)) {
      return Duration.zero;
    }
    return _soloud.getPosition(h);
  }

  @override
  bool get isPlaying {
    final h = _handle;
    return h != null && _soloud.getIsValidVoiceHandle(h);
  }

  @override
  Future<void> dispose() async {
    await stop();
    final source = _source;
    _source = null;
    if (source != null) {
      await _soloud.disposeSource(source);
    }
  }
}
