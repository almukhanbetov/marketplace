import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// Shared body for [EmptyView] / [ErrorView] and any other centred
/// "one icon + a line + maybe an action" state (§33/§34). Keeps all three
/// visually identical: a soft rounded icon chip, a bold title, a muted
/// helper line, an optional action — with a short fade-and-rise entrance
/// so a state change doesn't snap.
class NovaStateView extends StatelessWidget {
  const NovaStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor,
    this.iconBackground,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color? iconColor;
  final Color? iconBackground;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    final text = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? NovaSpace.lg : NovaSpace.xxl),
        child: _Entrance(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: iconBackground ?? c.surface2,
                  borderRadius: BorderRadius.circular(NovaRadii.lg),
                ),
                child: Icon(icon, size: 30, color: iconColor ?? c.text3),
              ),
              const Gap(NovaSpace.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Gap(NovaSpace.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium,
                ),
              ),
              if (action != null) ...[const Gap(NovaSpace.lg), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class _Entrance extends StatefulWidget {
  const _Entrance({required this.child});
  final Widget child;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance> {
  double _t = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _t = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _t,
      duration: NovaDurations.base,
      curve: NovaDurations.curve,
      child: AnimatedSlide(
        offset: Offset(0, (1 - _t) * 0.04),
        duration: NovaDurations.base,
        curve: NovaDurations.curve,
        child: widget.child,
      ),
    );
  }
}
