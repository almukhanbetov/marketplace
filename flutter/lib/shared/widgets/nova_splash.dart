import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// Shown while secure storage + the silent refresh resolve on launch
/// (Stage F2 §38) — never a blank frame.
class NovaSplash extends ConsumerWidget {
  const NovaSplash({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.nova;
    final s = ref.watch(appStringsProvider);
    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Wordmark(color: c.text, accent: c.accent),
              const SizedBox(height: 10),
              Text(
                s('app.tagline'),
                style: TextStyle(color: c.text2, fontSize: 13),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: c.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.color, required this.accent});
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent, accent.withValues(alpha: 0.7)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Text(
            'N',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'NOVA',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 26,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
