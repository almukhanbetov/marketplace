import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// A single shimmering placeholder block (§35). Drop-in replacement for the
/// flat grey `Container`s the skeleton screens used before — same size and
/// radius, but the surface sweeps so a slow network reads as "loading",
/// not "broken".
///
/// One [AnimationController] per box is fine here — skeletons are on screen
/// for a second or two and never in long lists.
class NovaSkeleton extends StatelessWidget {
  const NovaSkeleton({
    super.key,
    this.width,
    this.height,
    this.radius = NovaRadii.md,
    this.margin,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double? height;
  final double radius;
  final EdgeInsets? margin;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    return _Shimmer(
      base: c.surface2,
      highlight: c.surface3,
      child: Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: c.surface2,
          shape: shape,
          borderRadius: shape == BoxShape.circle
              ? null
              : BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// A vertical stack of skeleton rows — the common "list is loading" shape.
class NovaSkeletonList extends StatelessWidget {
  const NovaSkeletonList({
    super.key,
    this.count = 4,
    this.itemHeight = 96,
    this.radius = NovaRadii.md,
    this.padding = const EdgeInsets.all(NovaSpace.md),
    this.gap = NovaSpace.sm,
  });

  final int count;
  final double itemHeight;
  final double radius;
  final EdgeInsets padding;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      itemCount: count,
      separatorBuilder: (_, _) => SizedBox(height: gap),
      itemBuilder: (_, _) => NovaSkeleton(height: itemHeight, radius: radius),
    );
  }
}

class _Shimmer extends StatefulWidget {
  const _Shimmer({
    required this.child,
    required this.base,
    required this.highlight,
  });

  final Widget child;
  final Color base;
  final Color highlight;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1 - t * 2, 0),
            end: Alignment(1 - t * 2, 0),
            colors: [widget.base, widget.highlight, widget.base],
            stops: const [0.35, 0.5, 0.65],
          ).createShader(bounds),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
