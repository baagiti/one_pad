import 'dart:math';
import 'dart:typed_data';

/// Synthesized placeholder sounds for the session audio timeline.
///
/// Sound design is an open product decision (design doc §12); these exist so
/// the audio pipeline is fully self-contained. Swapping in recorded samples
/// later only means replacing these buffers — the renderer just mixes PCM.
class ClickSounds {
  final int sampleRate;

  /// Regular metronome click.
  late final Int16List click;

  /// Measure-start (accented) click.
  late final Int16List accent;

  /// Count-in click — must be audibly distinct (spec §6).
  late final Int16List countIn;

  /// Reference pad hit for preview playback (spec §5).
  late final Int16List padHit;

  ClickSounds({this.sampleRate = 44100}) {
    click = _sineBurst(freq: 1000, ms: 30, gain: 0.6);
    accent = _sineBurst(freq: 1500, ms: 35, gain: 0.8);
    countIn = _sineBurst(freq: 2200, ms: 40, gain: 0.8);
    padHit = _padThud();
  }

  Int16List _sineBurst(
      {required double freq, required int ms, required double gain}) {
    final n = sampleRate * ms ~/ 1000;
    final out = Int16List(n);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      // 1 ms linear attack avoids a start click; exponential decay after.
      final attack = min(1.0, i / (sampleRate * 0.001));
      final env = attack * exp(-t * 90);
      out[i] = (sin(2 * pi * freq * t) * env * gain * 32767).round();
    }
    return out;
  }

  /// Short noise burst over a low sine — reads as a muffled pad stroke and is
  /// clearly distinct from the metallic clicks.
  Int16List _padThud() {
    const ms = 60;
    final n = sampleRate * ms ~/ 1000;
    final out = Int16List(n);
    final rng = Random(1); // fixed seed: identical sound every build
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final attack = min(1.0, i / (sampleRate * 0.001));
      final noise = (rng.nextDouble() * 2 - 1) * exp(-t * 220) * 0.5;
      final thump = sin(2 * pi * 180 * t) * exp(-t * 60) * 0.7;
      out[i] = ((noise + thump) * attack * 0.7 * 32767)
          .round()
          .clamp(-32768, 32767);
    }
    return out;
  }
}
