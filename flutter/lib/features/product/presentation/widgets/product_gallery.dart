import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/nova_network_image.dart';

/// Swipeable product gallery with a page indicator. Tapping opens a
/// full-screen pinch-zoom viewer (§35). Falls back to a single placeholder
/// when there are no images.
class ProductGallery extends StatefulWidget {
  const ProductGallery({super.key, required this.images, this.heroTag});

  final List<String> images;
  final Object? heroTag;

  @override
  State<ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<ProductGallery> {
  final _pageCtl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    final images = widget.images.isEmpty ? <String?>[null] : widget.images;

    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageCtl,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: images.length,
            itemBuilder: (context, i) => GestureDetector(
              onTap: images[i] == null
                  ? null
                  : () => _openViewer(
                      context,
                      images.whereType<String>().toList(),
                      i,
                    ),
              child: Hero(
                tag: widget.heroTag ?? 'gallery-$i',
                child: NovaNetworkImage(url: images[i], fit: BoxFit.cover),
              ),
            ),
          ),
          if (images.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < images.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? c.accent
                            : c.textInverse.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _openViewer(BuildContext context, List<String> images, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullScreenGallery(images: images, initialIndex: index),
      ),
    );
  }
}

class _FullScreenGallery extends StatelessWidget {
  const _FullScreenGallery({required this.images, required this.initialIndex});

  final List<String> images;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: images.length,
        itemBuilder: (context, i) => InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: NovaNetworkImage(url: images[i], fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
