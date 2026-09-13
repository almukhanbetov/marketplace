import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_user.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/nova_feedback.dart';
import '../../../shared/widgets/nova_section_label.dart';

/// F2 scope: shows the real authenticated identity + logout / logout-all +
/// a seller-dashboard entry for sellers. Profile *editing*, orders and
/// favorites lists come in later stages (Stage F2 §41).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final auth = ref.watch(authControllerProvider);
    final c = context.nova;

    if (!auth.isAuthenticated || auth.user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s('nav.profile'))),
        body: EmptyView(
          icon: Icons.person_outline_rounded,
          title: s('profile.loggedOut.title'),
          body: s('profile.loggedOut.body'),
          action: FilledButton(
            onPressed: () => context.go(Routes.login),
            child: Text(s('action.login')),
          ),
        ),
      );
    }

    final user = auth.user!;
    return Scaffold(
      appBar: AppBar(title: Text(s('nav.profile'))),
      body: ListView(
        children: [
          _Header(user: user),
          if (user.hasSellerAccount) ...[
            const Gap(NovaSpace.xs),
            _SellerEntry(
              label: s('profile.action.sellerDashboard'),
              onTap: () => context.go(Routes.sellerDashboard),
            ),
          ],
          const Gap(NovaSpace.xs),
          _SectionLabel(s('profile.section.account')),
          _InfoRow(label: s('profile.field.name'), value: user.fullName),
          if (user.email != null)
            _InfoRow(label: s('profile.field.email'), value: user.email!),
          if (user.phone != null)
            _InfoRow(label: s('profile.field.phone'), value: user.phone!),
          _InfoRow(
            label: s('profile.field.role'),
            value: s('profile.role.${user.role}'),
          ),
          const SizedBox(height: 8),
          _SectionLabel(s('profile.section.shopping')),
          ListTile(
            leading: const Icon(Icons.favorite_border_rounded),
            title: Text(s('profile.action.favorites')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.go(Routes.favorites),
          ),
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: Text(s('profile.action.addresses')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.go(Routes.addresses),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text(s('profile.action.orders')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.go(Routes.orders),
          ),
          const Gap(NovaSpace.xs),
          _SectionLabel(s('profile.section.preferences')),
          ListTile(
            leading: const Icon(Icons.tune_rounded),
            title: Text(s('settings.title')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.go('${Routes.profile}/settings'),
          ),
          const Gap(NovaSpace.md),
          Padding(
            padding: NovaSpace.pagePadding,
            child: OutlinedButton.icon(
              onPressed: () => _logout(context, ref),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(s('profile.action.logout')),
            ),
          ),
          const Gap(NovaSpace.xs),
          Center(
            child: TextButton(
              onPressed: () => _logoutAll(context, ref, s),
              child: Text(
                s('profile.action.logoutAll'),
                style: TextStyle(color: c.text3, fontSize: 12.5),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).logout();
    if (context.mounted) context.go(Routes.home);
  }

  Future<void> _logoutAll(
    BuildContext context,
    WidgetRef ref,
    AppStrings s,
  ) async {
    final ok = await novaConfirm(
      context,
      title: s('profile.logoutAll.confirmTitle'),
      message: s('profile.logoutAll.confirmBody'),
      confirmLabel: s('profile.action.logoutAll'),
      cancelLabel: s('action.cancel'),
      destructive: true,
    );
    if (!ok) return;
    await ref.read(authControllerProvider.notifier).logoutAll();
    if (context.mounted) context.go(Routes.home);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});
  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    final initials = user.fullName.trim().isEmpty
        ? '?'
        : user.fullName
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((w) => w[0].toUpperCase())
              .join();
    return Container(
      margin: const EdgeInsets.fromLTRB(
        NovaSpace.md,
        NovaSpace.md,
        NovaSpace.md,
        NovaSpace.xs,
      ),
      padding: const EdgeInsets.all(NovaSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(NovaRadii.md),
        border: Border.all(color: c.border),
        boxShadow: NovaShadows.card(Theme.of(context).brightness),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: c.accentSoft,
            child: Text(
              initials,
              style: TextStyle(
                color: c.accent,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const Gap.h(NovaSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (user.email != null) ...[
                  const Gap(2),
                  Text(
                    user.email!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The seller-console entry — deliberately louder than the plain rows
/// above it (§26): an accent-tinted card with a storefront glyph.
class _SellerEntry extends StatelessWidget {
  const _SellerEntry({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    return Padding(
      padding: NovaSpace.pagePadding,
      child: Material(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(NovaRadii.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(NovaSpace.md),
            child: Row(
              children: [
                Icon(Icons.storefront_rounded, color: c.accent, size: 22),
                const Gap.h(NovaSpace.sm),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: c.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => NovaSectionLabel(text);
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: TextStyle(color: c.text3, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: c.text,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
