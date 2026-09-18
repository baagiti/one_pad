import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class _GripStep {
  final String title;
  final String body;
  final String tip;
  final String drawingDescription;
  final String image;

  const _GripStep({
    required this.title,
    required this.body,
    required this.tip,
    required this.drawingDescription,
    required this.image,
  });
}

const _steps = <_GripStep>[
  _GripStep(
    title: 'Find the balance point',
    body: "Measure about a third of the way up from the thick end (the "
        "butt). That's where you'll hold the stick, and where it bounces "
        'most freely.',
    tip: 'This spot is called the fulcrum. Nudge it a little up or down '
        'until the stick rebounds best.',
    drawingDescription: 'A drumstick with a ring marking one third of its '
        'length from the thick end, above a ruler split into thirds.',
    image: 'assets/images/grip/step1.jpg',
  ),
  _GripStep(
    title: 'Pinch it',
    body: 'Pinch the stick at the balance point between the pad of your '
        'thumb and the side of your index finger. This pinch is the pivot '
        'the stick swings on.',
    tip: 'Firm enough to control it, and no firmer.',
    drawingDescription: 'A close-up of a thumb and a curled index finger '
        'pinching a drumstick at the fulcrum.',
    image: 'assets/images/grip/step2.jpg',
  ),
  _GripStep(
    title: 'Wrap the other fingers',
    body: 'Let your middle, ring, and pinky fingers rest loosely around the '
        'stick, behind the pinch. About an inch of the thick end should peek '
        'out past your palm.',
    tip: 'Fingers rest on the stick; they never clamp it.',
    drawingDescription: 'A hand holding a drumstick, with three fingers '
        'resting around it and the thick end sticking out of the palm.',
    image: 'assets/images/grip/step3.jpg',
  ),
  _GripStep(
    title: 'Make a V over the pad',
    body: 'Turn both palms down and bring the sticks together over the pad '
        'so they form a V of about 90°, tips meeting near the center.',
    tip: 'Match your hands: same grip, same height, relaxed shoulders.',
    drawingDescription: "The player's view of two hands, palms down, "
        'holding sticks that meet over a practice pad in a V.',
    image: 'assets/images/grip/step4.jpg',
  ),
  _GripStep(
    title: 'Let it bounce',
    body: 'Lift the stick, let it drop, and let the pad throw it back up. '
        'Your job is to guide the rebound, not to push the stick into the '
        'pad.',
    tip: 'A loose grip lets the stick bounce; a tight one kills the sound.',
    drawingDescription: 'A side view of a stick tip on the pad, a faded '
        'copy of the stick raised above it and an arrow for the rebound.',
    image: 'assets/images/grip/step5.jpg',
  ),
];

/// "How to hold sticks" (opened from a small button at the top of Home): a
/// five-step, illustrated walkthrough of the matched grip. The pictures are
/// bundled renders from tool/grip_renders/grip3d.py, so the guide works
/// offline.
class HowToHoldSticksScreen extends StatefulWidget {
  const HowToHoldSticksScreen({super.key});

  @override
  State<HowToHoldSticksScreen> createState() => _HowToHoldSticksScreenState();
}

class _HowToHoldSticksScreenState extends State<HowToHoldSticksScreen> {
  final _pageController = PageController();
  int _page = 0;

  bool get _isLast => _page == _steps.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() {
    if (_isLast) {
      Navigator.of(context).pop();
    } else {
      _goTo(_page + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How to hold sticks')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _StepPage(
                  step: _steps[i],
                  number: i + 1,
                  total: _steps.length,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                children: [
                  _PageDots(count: _steps.length, current: _page),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _page == 0 ? null : () => _goTo(_page - 1),
                          child: const Text('Back'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _next,
                          child: Text(_isLast ? 'Got it' : 'Next'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  final _GripStep step;
  final int number;
  final int total;

  const _StepPage({
    required this.step,
    required this.number,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1280 / 880,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.outline),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: Semantics(
                  image: true,
                  label: step.drawingDescription,
                  child: Image.asset(
                    step.image,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'STEP $number OF $total',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(step.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            step.body,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    size: 20, color: AppColors.textPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    step.tip,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int current;

  const _PageDots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == current ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == current ? AppColors.primary : AppColors.outline,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
