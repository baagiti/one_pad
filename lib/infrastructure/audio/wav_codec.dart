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
