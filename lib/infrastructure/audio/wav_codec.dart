import 'dart:typed_data';

/// Wraps mono 16-bit PCM in a standard 44-byte WAV header so it can be handed
/// to the audio engine as an in-memory file.
Uint8List pcm16ToWav(Int16List pcm, {required int sampleRate}) {
  const channels = 1;
  const bitsPerSample = 16;
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final dataSize = pcm.length * 2;

  final bytes = BytesBuilder();
  void writeString(String s) => bytes.add(s.codeUnits);
  void writeU32(int v) =>
      bytes.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void writeU16(int v) =>
      bytes.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());

  writeString('RIFF');
  writeU32(36 + dataSize);
  writeString('WAVE');
  writeString('fmt ');
  writeU32(16); // PCM fmt chunk size
  writeU16(1); // PCM format
  writeU16(channels);
  writeU32(sampleRate);
  writeU32(byteRate);
  writeU16(channels * bitsPerSample ~/ 8); // block align
  writeU16(bitsPerSample);
  writeString('data');
  writeU32(dataSize);
  bytes.add(pcm.buffer.asUint8List(pcm.offsetInBytes, dataSize));

  return bytes.toBytes();
}

class WavAudio {
  final int sampleRate;
  final int channels;

  /// Interleaved 16-bit PCM samples (frame-major: LRLRLR... for stereo).
  final Int16List samples;

  const WavAudio({
    required this.sampleRate,
    required this.channels,
    required this.samples,
  });

  /// Down-mixed to mono, normalized to [-1, 1] — the input format M4's
  /// [OnsetDetector] (an FFT over doubles) expects.
  Float64List toMonoDoubles() {
    final frames = samples.length ~/ channels;
    final out = Float64List(frames);
    for (var i = 0; i < frames; i++) {
      var sum = 0;
      for (var c = 0; c < channels; c++) {
        sum += samples[i * channels + c];
      }
      out[i] = (sum / channels) / 32768.0;
    }
    return out;
  }
}

/// Decodes a WAV file back to PCM (the inverse of [pcm16ToWav]) — used by
/// M4 to analyze a Record-mode take. Scans chunks by id/size rather than
/// assuming a fixed 44-byte header: the file was written by
/// `flutter_recorder`'s native encoder, not by [pcm16ToWav], so its exact
/// chunk layout isn't guaranteed to match.
WavAudio wavToPcm16(Uint8List bytes) {
  if (bytes.length < 12 ||
      String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
      String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
    throw const FormatException('Not a RIFF/WAVE file');
  }
  final data = ByteData.sublistView(bytes);

  int? sampleRate;
  int? channels;
  int? bitsPerSample;
  int? dataOffset;
  int? dataLength;

  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final size = data.getUint32(offset + 4, Endian.little);
    final bodyStart = offset + 8;
    if (id == 'fmt ') {
      channels = data.getUint16(bodyStart + 2, Endian.little);
      sampleRate = data.getUint32(bodyStart + 4, Endian.little);
      bitsPerSample = data.getUint16(bodyStart + 14, Endian.little);
    } else if (id == 'data') {
      dataOffset = bodyStart;
      dataLength = size;
    }
    // Chunks are word-aligned: an odd-sized body is followed by one pad byte.
    offset = bodyStart + size + (size.isOdd ? 1 : 0);
  }

  if (sampleRate == null ||
      channels == null ||
      bitsPerSample == null ||
      dataOffset == null ||
      dataLength == null) {
    throw const FormatException('WAV file is missing fmt or data chunk');
  }
  if (bitsPerSample != 16) {
    throw UnsupportedError(
        'Only 16-bit PCM WAV is supported, got $bitsPerSample-bit');
  }

  final clippedLength = dataLength.clamp(0, bytes.length - dataOffset);
  final sampleCount = clippedLength ~/ 2;
  final samples = Int16List(sampleCount);
  for (var i = 0; i < sampleCount; i++) {
    samples[i] = data.getInt16(dataOffset + i * 2, Endian.little);
  }

  return WavAudio(sampleRate: sampleRate, channels: channels, samples: samples);
}
