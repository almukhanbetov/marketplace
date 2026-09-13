import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Network image with a stable box (no layout jump), a shimmering
/// placeholder, and a graceful icon on failure or a null/blank URL
/// (Stage F3 §30/§31). Backed by `cached_network_image` so scrolling a
/// grid doesn't re-download.
class NovaNetworkImage extends StatelessWidget {
  const NovaNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String? url;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    final radius = borderRadius ?? BorderRadius.zero;

    Widget fallback(IconData icon) => DecoratedBox(
      decoration: BoxDecoration(color: c.surface2, borderRadius: radius),
      child: Center(child: Icon(icon, color: c.text3, size: 28)),
    );

    if (url == null || url!.trim().isEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: fallback(Icons.image_outlined),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: url!,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, _) =>
            _Shimmer(color: c.surface2, highlight: c.surface3),
        errorWidget: (_, _, _) => fallback(Icons.broken_image_outlined),
      ),
    );
  }
}

class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.color, required this.highlight});
  final Color color;
  final Color highlight;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
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
      builder: (context, _) {
        final t = _c.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 - t * 2, 0),
              end: Alignment(1 - t * 2, 0),
              colors: [widget.color, widget.highlight, widget.color],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}
