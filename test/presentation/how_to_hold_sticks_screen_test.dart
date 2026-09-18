import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/application/session_flow/practice_flow_controller.dart';
import 'package:one_pad/domain/content/content_loader.dart';
import 'package:one_pad/infrastructure/ads/ads_service.dart';
import 'package:one_pad/infrastructure/audio/audio_engine.dart';
import 'package:one_pad/infrastructure/audio/audio_recorder.dart';
import 'package:one_pad/infrastructure/audio/click_sounds.dart';
import 'package:one_pad/infrastructure/iap/purchase_service.dart';
import 'package:one_pad/infrastructure/storage/app_database.dart';
import 'package:one_pad/presentation/screens/home_screen.dart';
import 'package:one_pad/presentation/screens/how_to_hold_sticks_screen.dart';
import 'package:one_pad/presentation/theme/app_theme.dart';

class _NoopEngine implements AudioEngine {
  @override
  Future<void> init() async {}
  @override
  Future<void> loadSession(Uint8List wavBytes) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> stop() async {}
  @override
  Duration get position => Duration.zero;
  @override
  bool get isPlaying => false;
  @override
  Future<void> dispose() async {}
}

class _NoopRecorder implements AudioRecorder {
  @override
  Future<void> init() async {}
  @override
  void startRecording(String filePath) {}
  @override
  void stopRecording() {}
  @override
  void dispose() {}
}

void main() {
  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('walks through all five steps and closes on the last one',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const HowToHoldSticksScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('STEP 1 OF 5'), findsOneWidget);
    expect(find.text('Find the balance point'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Back'))
          .onPressed,
      isNull,
    );

    const titles = [
      'Pinch it',
      'Wrap the other fingers',
      'Make a V over the pad',
      'Let it bounce',
    ];
    for (var i = 0; i < titles.length; i++) {
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();
      expect(find.text('STEP ${i + 2} OF 5'), findsOneWidget);
      expect(find.text(titles[i]), findsOneWidget);
    }

    expect(find.widgetWithText(FilledButton, 'Got it'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Back'));
    await tester.pumpAndSettle();
    expect(find.text('STEP 4 OF 5'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Got it'));
    await tester.pumpAndSettle();
    expect(find.byType(HowToHoldSticksScreen), findsNothing);
  });

  testWidgets('the guide fits a small phone without overflowing',
      (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 568 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const HowToHoldSticksScreen()),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home has a How to hold sticks button that opens the guide',
      (tester) async {
    // Keeps the real-ads code path off (AdsService.supported is false).
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    usePhoneSurface(tester);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final loader = ContentLoader();
    final skills = [
      for (final f in Directory('content/skills')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json')))
        loader.loadSkill(f.readAsStringSync()),
    ];
    final controller = PracticeFlowController(
      engine: _NoopEngine(),
      recorder: _NoopRecorder(),
      sounds: ClickSounds(sampleRate: PracticeFlowController.sampleRate),
    );

    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: HomeScreen(
            controller: controller,
            skills: skills,
            db: db,
            purchases: PurchaseService(db: db),
            ads: AdsService(),
          ),
        ),
      );
      // drift/sqlite answer on real async time, not the fake test clock.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      final button = find.byKey(const Key('how_to_hold_button'));
      expect(button, findsOneWidget);
      expect(find.text('How to hold sticks'), findsOneWidget);

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(HowToHoldSticksScreen), findsOneWidget);
      expect(find.text('STEP 1 OF 5'), findsOneWidget);

      // Unmount so the drift stream subscriptions are cancelled. The
      // in-memory database is left open: closing it under the fake test
      // clock waits on timers that never fire.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
