import 'package:flutter_recorder/flutter_recorder.dart';

/// Microphone-capture abstraction (design doc §9, M3). Kept minimal on
/// purpose: init the device once, start/stop writing a take to a WAV file.
/// No streaming/FFT here — that's M4's onset-detection concern, added on top
/// of this once a take can be reliably captured and replayed.
abstract class AudioRecorder {
  Future<void> init();

  /// Starts capturing microphone input into [filePath] (WAV). Starts the
  /// capture device on first use.
  void startRecording(String filePath);

  /// Finalizes the WAV file at the path passed to [startRecording]. The
  /// capture device itself is left running so a second take can start
  /// immediately without re-opening it.
  void stopRecording();

  void dispose();
}

class FlutterRecorderAudioRecorder implements AudioRecorder {
  /// Matches [PracticeFlowController.sampleRate] (not flutter_recorder's own
  /// 22050 default) so recorded sample offsets line up with TimelineMap
  /// without conversion — M4's onset matching depends on this.
  static const sampleRate = 44100;

  final Recorder _recorder = Recorder.instance;
  bool _deviceStarted = false;

  @override
  Future<void> init() async {
    if (!_recorder.isDeviceInitialized()) {
      await _recorder.init(
        sampleRate: sampleRate,
        channels: RecorderChannels.mono,
      );
    }
  }

  @override
  void startRecording(String filePath) {
    if (!_deviceStarted) {
      _recorder.start();
      _deviceStarted = true;
    }
    _recorder.startRecording(completeFilePath: filePath);
  }

  @override
  void stopRecording() {
    _recorder.stopRecording();
  }

  @override
  void dispose() {
    _recorder.deinit();
    _deviceStarted = false;
  }
}
