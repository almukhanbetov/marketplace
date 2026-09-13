import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/nova_feedback.dart';
import '../../../shared/widgets/nova_skeleton.dart';
import '../application/addresses_controller.dart';
import '../data/address_models.dart';
import 'address_form_screen.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final state = ref.watch(addressesControllerProvider);
    final controller = ref.read(addressesControllerProvider.notifier);

    Future<void> openForm([AddressModel? existing]) async {
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => AddressFormScreen(existing: existing),
        ),
      );
      if (saved == true && context.mounted) {
        NovaSnackbar.success(context, s('address.save'));
      }
    }

    Widget body;
    if (state.isFirstLoad || state.status == AddressesStatus.initial) {
      body = const _AddrSkeleton();
    } else if (state.status == AddressesStatus.error && state.items.isEmpty) {
      body = ErrorView(error: state.error, onRetry: controller.refresh);
    } else if (state.isEmpty) {
      body = EmptyView(
        icon: Icons.location_on_outlined,
        title: s('address.empty.title'),
        body: s('address.empty.body'),
        action: FilledButton.icon(
          onPressed: openForm,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(s('address.add')),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            NovaSpace.md,
            NovaSpace.sm,
            NovaSpace.md,
            NovaSpace.xl,
          ),
          children: [
            for (final a in state.items)
              _AddressCard(
                address: a,
                busy: state.mutating,
                onEdit: () => openForm(a),
                onMakeDefault: () =>
                    _guard(context, s, () => controller.setDefault(a.id)),
                onDelete: () =>
                    _confirmDelete(context, s, () => controller.delete(a.id)),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(s('address.title')),
        actions: [
          if (state.status == AddressesStatus.loaded && state.items.isNotEmpty)
            IconButton(
              onPressed: openForm,
              icon: const Icon(Icons.add_rounded),
              tooltip: s('address.add'),
            ),
        ],
      ),
      body: body,
    );
  }

  Future<void> _guard(
    BuildContext context,
    AppStrings s,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on ApiException catch (e) {
      if (context.mounted) NovaSnackbar.error(context, s.apiError(e.code));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppStrings s,
    Future<void> Function() action,
  ) async {
    final ok = await novaConfirm(
      context,
      title: s('address.delete.confirmTitle'),
      message: s('address.delete.confirmBody'),
      confirmLabel: s('action.delete'),
      cancelLabel: s('action.cancel'),
      destructive: true,
    );
    if (ok && context.mounted) await _guard(context, s, action);
  }
}

class _AddressCard extends ConsumerWidget {
  const _AddressCard({
    required this.address,
    required this.busy,
    required this.onEdit,
    required this.onMakeDefault,
    required this.onDelete,
  });

  final AddressModel address;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onMakeDefault;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    return Container(
      margin: const EdgeInsets.only(bottom: NovaSpace.sm),
      padding: const EdgeInsets.fromLTRB(NovaSpace.md, NovaSpace.sm, 6, 8),
      decoration: BoxDecoration(
        color: address.isDefault ? c.accentSoft : c.surface,
        borderRadius: BorderRadius.circular(NovaRadii.md),
        border: Border.all(
          color: address.isDefault ? c.accent : c.border,
          width: address.isDefault ? 1.4 : 1,
        ),
        boxShadow: address.isDefault
            ? null
            : NovaShadows.card(Theme.of(context).brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if ((address.title ?? '').isNotEmpty)
                Text(
                  address.title!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              const SizedBox(width: 8),
              if (address.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: c.accentSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    s('address.default'),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: c.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${address.city}, ${address.oneLine}',
            style: TextStyle(fontSize: 13, color: c.text2, height: 1.35),
          ),
          if ((address.postalCode ?? '').isNotEmpty)
            Text(
              address.postalCode!,
              style: TextStyle(fontSize: 11.5, color: c.text3),
            ),
          Row(
            children: [
              if (!address.isDefault)
                TextButton(
                  onPressed: busy ? null : onMakeDefault,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 40),
                  ),
                  child: Text(s('address.makeDefault')),
                ),
              const Spacer(),
              IconButton(
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: s('action.edit'),
              ),
              IconButton(
                onPressed: busy ? null : onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                tooltip: s('action.delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddrSkeleton extends StatelessWidget {
  const _AddrSkeleton();

  @override
  Widget build(BuildContext context) =>
      const NovaSkeletonList(count: 3, itemHeight: 96);
}
