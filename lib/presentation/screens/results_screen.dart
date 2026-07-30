import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../application/session_flow/practice_flow_controller.dart';
import '../../domain/analysis/expected_onsets.dart';
import '../../domain/analysis/latency_search.dart';
import '../../domain/analysis/onset_detector.dart';
import '../../domain/analysis/timing_scorer.dart';
import '../../infrastructure/ads/ads_service.dart';
import '../../infrastructure/audio/wav_codec.dart';
import '../../infrastructure/storage/app_database.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_banner.dart';
import '../widgets/drum_head_background.dart';
import 'practice_screen.dart';

/// Results: v1 skeleton. Content beyond M4's score is an open product
/// decision (design doc §12).
///
/// M3 added Play/Stop for a just-recorded take (loads the captured WAV back
/// through the same idle [AudioEngine] used for practice playback). M4 adds
/// the actual grading: decode the take, detect onsets, and score them
/// against the session's expected timing (2026-07-22 decision: a single
/// overall grade, not a per-exercise breakdown, for this iteration).
class ResultsScreen extends StatefulWidget {
  final PracticeFlowController controller;
  final AppDatabase db;
  final AdsService ads;

  const ResultsScreen({
    super.key,
    required this.controller,
    required this.db,
    required this.ads,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  PracticeFlowController get controller => widget.controller;

  bool _loadingPlayback = false;
  bool _playingRecording = false;
  Timer? _playbackWatch;

  bool _analyzing = false;
  SessionScore? _score;
  bool _premium = false;

  @override
  void initState() {
    super.initState();
    if (controller.recordingPath != null) _analyze();
    _checkPremiumAndShowAd();
  }

  /// Post-session interstitial for free users only (design doc, 2026-07-30)
  /// — fire-and-forget, an ad is a bonus screen, never something the results
  /// UI waits on. Deferred to after the first frame so it never contends
  /// with this screen's own build/analysis.
  Future<void> _checkPremiumAndShowAd() async {
    final premium = await widget.db.isPremium();
    if (!mounted) return;
    setState(() => _premium = premium);
    if (!premium) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.ads.showInterstitial();
      });
    }
  }

  Future<void> _analyze() async {
    setState(() => _analyzing = true);
    final path = controller.recordingPath!;
    final map = controller.map!;
    final exercises = controller.session!.exercises;

    final bytes = await File(path).readAsBytes();
    final recorded = wavToPcm16(bytes);
    final detected = OnsetDetector(
      sampleRate: recorded.sampleRate,
    ).detect(recorded.toMonoDoubles());

    // Auto-detect this take's own alignment offset rather than trusting a
    // separately-measured device calibration (2026-07-27): a short
    // calibration click track measured ~271ms round-trip on one machine,
    // but a real ~38s Record-mode session needed a very different offset to
    // align — close enough in timing character that a fixed number from a
    // different recording just isn't reliable enough to grade against.
    final expected = <int>[
      for (final e in exercises) ...expectedOnsetSamples(map, e),
    ];
    final latencySamples = findBestLatencySamples(
      expectedSamples: expected,
      detectedSamples: detected,
      searchToSamples: recorded.sampleRate * 2, // 2s, generous
    );

    final score = TimingScorer().score(
      map: map,
      exercises: exercises,
      detectedOnsetSamples: detected,
      latencySamples: latencySamples,
    );
    if (!mounted) return;
    setState(() {
      _score = score;
      _analyzing = false;
    });
  }

  Future<void> _toggleRecordingPlayback() async {
    if (_playingRecording) {
      await controller.engine.stop();
      _stopWatchingPlayback();
      setState(() => _playingRecording = false);
      return;
    }
    final path = controller.recordingPath;
    if (path == null) return;
    setState(() => _loadingPlayback = true);
    final bytes = await File(path).readAsBytes();
    await controller.engine.loadSession(Uint8List.fromList(bytes));
    await controller.engine.play();
    if (!mounted) return;
    setState(() {
      _loadingPlayback = false;
      _playingRecording = true;
    });
    // No frame ticker on this screen; a light poll is enough to flip the
    // button back once the take finishes playing on its own.
    _playbackWatch = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!controller.engine.isPlaying) {
        _stopWatchingPlayback();
        if (mounted) setState(() => _playingRecording = false);
      }
    });
  }

  void _stopWatchingPlayback() {
    _playbackWatch?.cancel();
    _playbackWatch = null;
  }

  @override
  void dispose() {
    _stopWatchingPlayback();
    if (_playingRecording) controller.engine.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = controller.session!;
    final recordingPath = controller.recordingPath;

    return Scaffold(
      appBar: AppBar(title: const Text('Session Complete')),
      body: Stack(
        children: [
          const Positioned.fill(child: DrumHeadBackground()),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 72,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nice work!',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${session.exercises.length} exercises · ${session.bpm} BPM',
                      textAlign: TextAlign.center,
                    ),
                    if (recordingPath != null) ...[
                      const SizedBox(height: 20),
                      _buildScore(context),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _loadingPlayback
                            ? null
                            : _toggleRecordingPlayback,
                        icon: Icon(
                          _playingRecording ? Icons.stop : Icons.play_arrow,
                        ),
                        label: Text(
                          _playingRecording ? 'Stop' : 'Play Recording',
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => PracticeScreen(
                              controller: controller,
                              db: widget.db,
                              ads: widget.ads,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.replay),
                      label: const Text('Practice Again'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.of(context).popUntil((r) => r.isFirst),
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('Home'),
                    ),
                    if (!_premium) ...[
                      const SizedBox(height: 16),
                      AdBanner(ads: widget.ads),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScore(BuildContext context) {
    if (_analyzing) {
      return const Column(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(height: 8),
          Text('Analyzing your take…'),
        ],
      );
    }
    final score = _score;
    if (score == null) return const SizedBox.shrink();
    final grade = score.grade;
    final color = grade >= 80
        ? AppColors.success
        : (grade >= 50 ? AppColors.secondary : AppColors.error);
    return Column(
      children: [
        Text(
          '$grade%',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'timing accuracy',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}
