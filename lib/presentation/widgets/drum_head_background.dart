import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Real practice-pad photo (mesh head, rim, sticks — logo-cropped, Pexels
/// license, 2026-07-27) behind a screen's content, fading into the flat
/// theme background lower down so the scrolling lesson list stays legible
/// — evokes "you're looking down at the pad" without a hand-drawn stand-in.
class DrumHeadBackground extends StatelessWidget {
  const DrumHeadBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/drum_pad_bg.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.background.withValues(alpha: 0.25),
                AppColors.background.withValues(alpha: 0.6),
                AppColors.background,
              ],
              stops: const [0.0, 0.42, 0.62],
            ),
          ),
        ),
      ],
    );
  }
}
