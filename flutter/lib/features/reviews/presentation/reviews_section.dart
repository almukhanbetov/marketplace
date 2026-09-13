import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/error_view.dart';
import '../application/reviews_provider.dart';
import '../data/review_models.dart';

/// Read-only public reviews for a product (§44–§46). First page loads
/// automatically; "Show more" pulls the next page.
class ReviewsSection extends ConsumerWidget {
  const ReviewsSection({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final state = ref.watch(reviewsProvider(productId));
    final controller = ref.read(reviewsProvider(productId).notifier);

    if (state.isFirstLoad) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (state.status == ReviewsStatus.error && state.items.isEmpty) {
      return ErrorView(error: state.error, onRetry: controller.refresh);
    }

    if (state.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Row(
          children: [
            Icon(Icons.rate_review_outlined, color: c.text3, size: 20),
            const SizedBox(width: 10),
            Text(
              s('review.empty'),
              style: TextStyle(color: c.text2, fontSize: 13.5),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in state.items) _ReviewTile(review: r),
        if (state.hasMore)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: OutlinedButton(
              onPressed: state.status == ReviewsStatus.loadingMore
                  ? null
                  : controller.loadMore,
              child: state.status == ReviewsStatus.loadingMore
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(s('review.showMore')),
            ),
          ),
        if (state.status == ReviewsStatus.errorMore)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextButton(
              onPressed: controller.loadMore,
              child: Text(s('action.retry')),
            ),
          ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final ReviewModel review;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(
                  i <= review.rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 15,
                  color: c.star,
                ),
              const Spacer(),
              Text(
                _fmtDate(review.createdAt),
                style: TextStyle(fontSize: 11, color: c.text3),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            review.userDisplayName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          if (review.text.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              review.text,
              style: TextStyle(fontSize: 13, height: 1.35, color: c.text2),
            ),
          ],
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
