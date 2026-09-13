import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/nova_section_label.dart';
import '../../../../shared/widgets/nova_skeleton.dart';
import '../../payouts/application/payout_request_controller.dart';
import '../../payouts/presentation/widgets/request_payout_sheet.dart';
import '../application/seller_finance_controller.dart';
import '../data/seller_finance_models.dart';

/// `GET /seller/finance` — real figures, no client-side accounting
/// (Stage F6D §4/§5). Makes the "only available balance is withdrawable"
/// rule explicit (§9).
class SellerFinanceScreen extends ConsumerWidget {
  const SellerFinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final state = ref.watch(sellerFinanceControllerProvider);
    final controller = ref.read(sellerFinanceControllerProvider.notifier);

    Widget body;
    switch (state.status) {
      case SellerFinanceStatus.loading:
        body = const _FinanceSkeleton();
      case SellerFinanceStatus.error:
        body = ErrorView(error: state.error, onRetry: controller.refresh);
      case SellerFinanceStatus.loaded:
        body = RefreshIndicator(
          onRefresh: controller.refresh,
          child: _Content(data: state.data!),
        );
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(s('seller.finance.title'))),
      body: body,
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.data});
  final SellerFinanceModel data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    Future<void> openRequest() async {
      ref.read(payoutRequestControllerProvider.notifier).startNewAttempt();
      await showRequestPayoutSheet(
        context,
        availableBalance: data.availableBalance,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        NovaSpace.md,
        NovaSpace.sm,
        NovaSpace.md,
        NovaSpace.xl,
      ),
      children: [
        // ---- balances: the withdrawable distinction is the headline ----
        _BalanceCard(
          tone: _Tone.accent,
          label: s('seller.finance.available'),
          value: Money.format(data.availableBalance),
          note: s('seller.finance.availableNote'),
        ),
        const Gap(NovaSpace.sm),
        _BalanceCard(
          tone: _Tone.neutral,
          label: s('seller.finance.pending'),
          value: Money.format(data.pendingBalance),
          note: s('seller.finance.pendingNote'),
        ),
        const Gap(NovaSpace.md),
        FilledButton.icon(
          onPressed: openRequest,
          icon: const Icon(Icons.north_east_rounded, size: 18),
          label: Text(s('payout.request.title')),
        ),
        const Gap(NovaSpace.xs),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: () => context.push(Routes.sellerPayouts),
            child: Text(s('seller.finance.viewPayouts')),
          ),
        ),
        const Gap(NovaSpace.md),

        NovaSectionLabel(
          s('seller.finance.breakdown'),
          padding: EdgeInsets.zero,
        ),
        const Gap(NovaSpace.xs),
        Container(
          padding: const EdgeInsets.all(NovaSpace.md),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(NovaRadii.md),
            border: Border.all(color: c.border),
          ),
          child: Column(
            children: [
              _Row(
                label: s('seller.finance.grossSales'),
                value: Money.format(data.grossSales),
              ),
              _Row(
                label: s('seller.finance.commission'),
                value: '−${Money.format(data.commissionTotal)}',
              ),
              const Divider(height: 18),
              _Row(
                label: s('seller.finance.net'),
                value: Money.format(data.sellerNetTotal),
                emphasize: true,
              ),
              const Divider(height: 18),
              _Row(
                label: s('seller.finance.paidOut'),
                value: Money.format(data.paidOutTotal),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _Tone { accent, neutral }

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.tone,
    required this.label,
    required this.value,
    required this.note,
  });

  final _Tone tone;
  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    final (fg, bg, border) = switch (tone) {
      _Tone.accent => (c.accent, c.accentSoft, c.accent),
      _Tone.neutral => (c.text2, c.surface, c.border),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: c.text2)),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: tone == _Tone.accent ? fg : c.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: TextStyle(fontSize: 11.5, color: c.text3, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.emphasize = false,
  });
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: emphasize ? 14 : 13,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400,
                color: emphasize ? c.text : c.text2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasize ? 15 : 13,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              color: emphasize ? c.price : c.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceSkeleton extends StatelessWidget {
  const _FinanceSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(NovaSpace.md),
      children: const [
        NovaSkeleton(height: 96, margin: EdgeInsets.only(bottom: NovaSpace.sm)),
        NovaSkeleton(height: 96, margin: EdgeInsets.only(bottom: NovaSpace.sm)),
        NovaSkeleton(height: 44, margin: EdgeInsets.only(bottom: NovaSpace.sm)),
        NovaSkeleton(
          height: 180,
          margin: EdgeInsets.only(bottom: NovaSpace.sm),
        ),
      ],
    );
  }
}
