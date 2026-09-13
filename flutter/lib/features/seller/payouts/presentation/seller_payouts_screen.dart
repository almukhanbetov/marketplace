import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/widgets/empty_view.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/nova_skeleton.dart';
import '../../finance/application/seller_finance_controller.dart';
import '../application/payout_request_controller.dart';
import '../application/seller_payouts_controller.dart';
import 'widgets/payout_row.dart';
import 'widgets/request_payout_sheet.dart';

/// `GET /seller/payouts` + `POST /seller/payouts`. The list is read-only
/// history; the FAB opens the request sheet (Stage F6D §6/§8).
class SellerPayoutsScreen extends ConsumerWidget {
  const SellerPayoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final state = ref.watch(sellerPayoutsControllerProvider);
    final controller = ref.read(sellerPayoutsControllerProvider.notifier);
    final finance = ref.watch(sellerFinanceControllerProvider);
    final available = finance.data?.availableBalance;

    Future<void> openRequest() async {
      // A fresh idempotency key for a genuinely new attempt.
      ref.read(payoutRequestControllerProvider.notifier).startNewAttempt();
      await showRequestPayoutSheet(context, availableBalance: available ?? '0');
    }

    Widget body;
    if (state.isFirstLoad) {
      body = const _PayoutsSkeleton();
    } else if (state.status == SellerPayoutsStatus.error &&
        state.items.isEmpty) {
      body = ErrorView(error: state.error, onRetry: controller.refresh);
    } else if (state.isEmpty) {
      body = EmptyView(
        icon: Icons.account_balance_outlined,
        title: s('payout.empty.title'),
        body: s('payout.empty.body'),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () async {
          await controller.refresh();
          await ref.read(sellerFinanceControllerProvider.notifier).refresh();
        },
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: state.items.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return _AvailableBanner(available: available);
            }
            return PayoutRow(payout: state.items[i - 1]);
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(s('payout.title'))),
      floatingActionButton: available == null
          ? null
          : FloatingActionButton.extended(
              onPressed: openRequest,
              icon: const Icon(Icons.north_east_rounded),
              label: Text(s('payout.request.title')),
            ),
      body: body,
    );
  }
}

class _AvailableBanner extends ConsumerWidget {
  const _AvailableBanner({required this.available});
  final String? available;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (available == null) return const SizedBox.shrink();
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s('payout.availableToWithdraw'),
                  style: TextStyle(fontSize: 11.5, color: c.text2),
                ),
                Text(
                  Money.format(available!),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: c.accent,
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

class _PayoutsSkeleton extends StatelessWidget {
  const _PayoutsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(NovaSpace.md),
      children: const [
        NovaSkeleton(height: 70, margin: EdgeInsets.only(bottom: NovaSpace.sm)),
        NovaSkeleton(height: 88, margin: EdgeInsets.only(bottom: NovaSpace.sm)),
        NovaSkeleton(height: 88, margin: EdgeInsets.only(bottom: NovaSpace.sm)),
        NovaSkeleton(height: 88, margin: EdgeInsets.only(bottom: NovaSpace.sm)),
      ],
    );
  }
}
