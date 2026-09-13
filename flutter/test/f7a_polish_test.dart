import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_marketplace/core/storage/preferences_store.dart';
import 'package:nova_marketplace/core/storage/secure_storage.dart';
import 'package:nova_marketplace/core/theme/app_dimens.dart';
import 'package:nova_marketplace/core/theme/app_theme.dart';
import 'package:nova_marketplace/features/orders/data/order_models.dart';
import 'package:nova_marketplace/features/orders/presentation/widgets/order_card.dart';
import 'package:nova_marketplace/shared/widgets/empty_view.dart';
import 'package:nova_marketplace/shared/widgets/error_view.dart';
import 'package:nova_marketplace/shared/widgets/nova_feedback.dart';
import 'package:nova_marketplace/shared/widgets/nova_section_label.dart';
import 'package:nova_marketplace/shared/widgets/nova_skeleton.dart';
import 'package:nova_marketplace/shared/widgets/nova_sticky_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_harness.dart';

/// Stage F7A — the shared design-system layer: tokens, the state views,
/// skeletons, feedback helpers, and text-scale / theme resilience of the
/// widgets those touch.

Future<Widget> _host(
  Widget child, {
  ThemeData? theme,
  double textScale = 1.0,
  Size size = const Size(390, 844),
}) async {
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  return ProviderScope(
    retry: (_, _) => null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      secureStoreProvider.overrideWithValue(FakeSecureStore()),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: child),
      ),
    ),
  );
}

Future<void> _pump(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  group('layout tokens', () {
    test('spacing scale is the short 4→32 ramp, in order', () {
      const scale = [
        NovaSpace.xxs,
        NovaSpace.xs,
        NovaSpace.sm,
        NovaSpace.md,
        NovaSpace.lg,
        NovaSpace.xl,
        NovaSpace.xxl,
      ];
      expect(scale, [4.0, 8.0, 12.0, 16.0, 20.0, 24.0, 32.0]);
      for (var i = 1; i < scale.length; i++) {
        expect(scale[i], greaterThan(scale[i - 1]));
      }
      expect(NovaSpace.gutter, 16.0);
    });

    test('radii are the four steps, ascending, pill is fully round', () {
      expect(
        [NovaRadii.xs, NovaRadii.sm, NovaRadii.md, NovaRadii.lg],
        [8.0, 10.0, 14.0, 18.0],
      );
      expect(NovaRadii.pill, greaterThan(NovaRadii.lg));
    });

    test('every motion duration sits in the 150–300ms band (§39)', () {
      for (final d in [
        NovaDurations.fast,
        NovaDurations.base,
        NovaDurations.slow,
      ]) {
        expect(d.inMilliseconds, inInclusiveRange(150, 300));
      }
    });

    test('card shadow: none in dark, soft lift in light (§9)', () {
      expect(NovaShadows.card(Brightness.dark), isEmpty);
      expect(NovaShadows.card(Brightness.light), isNotEmpty);
    });
  });

  group('theme polish', () {
    test('light scaffold stays exactly #FFFFFF (§4)', () {
      expect(AppTheme.light().scaffoldBackgroundColor, const Color(0xFFFFFFFF));
    });

    test('dark scaffold stays near-black graphite (§5)', () {
      expect(AppTheme.dark().scaffoldBackgroundColor, const Color(0xFF0A0B0D));
    });

    test('buttons are ≥ 48px tall — comfortable touch targets (§10)', () {
      final size = AppTheme.light().filledButtonTheme.style!.minimumSize!
          .resolve({});
      expect(size!.height, greaterThanOrEqualTo(48));
    });

    test('bottom sheets show a drag handle (§38)', () {
      expect(AppTheme.light().bottomSheetTheme.showDragHandle, isTrue);
    });

    test('typography exposes the full named hierarchy (§6)', () {
      final t = AppTheme.light().textTheme;
      for (final style in [
        t.displaySmall,
        t.headlineMedium,
        t.headlineSmall,
        t.titleLarge,
        t.titleMedium,
        t.titleSmall,
        t.bodyLarge,
        t.bodyMedium,
        t.bodySmall,
        t.labelLarge,
        t.labelSmall,
      ]) {
        expect(style, isNotNull);
        expect(style!.fontSize, isNotNull);
      }
    });
  });

  group('EmptyView / ErrorView', () {
    testWidgets('EmptyView shows icon, title and body', (tester) async {
      await tester.pumpWidget(
        await _host(
          const EmptyView(
            icon: Icons.inbox_outlined,
            title: 'Nothing here',
            body: 'Come back later',
          ),
        ),
      );
      await _pump(tester);
      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.text('Come back later'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ErrorView Retry button invokes the callback', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        await _host(ErrorView(message: 'Boom', onRetry: () => retried++)),
      );
      await _pump(tester);
      expect(find.text('Boom'), findsOneWidget);
      await tester.tap(find.byType(OutlinedButton));
      expect(retried, 1);
    });

    for (final theme in {
      'light': AppTheme.light(),
      'dark': AppTheme.dark(),
    }.entries) {
      for (final scale in [1.0, 1.2, 1.4]) {
        testWidgets(
          'state views render clean — ${theme.key} @ textScale $scale '
          '(§34/§42/§51)',
          (tester) async {
            await tester.pumpWidget(
              await _host(
                Column(
                  children: [
                    const Expanded(
                      child: EmptyView(title: 'A', body: 'bbbbb bbbbb bbbbb'),
                    ),
                    Expanded(
                      child: ErrorView(message: 'ccccc ccccc', onRetry: () {}),
                    ),
                  ],
                ),
                theme: theme.value,
                textScale: scale,
              ),
            );
            await _pump(tester);
            expect(
              tester.takeException(),
              isNull,
              reason: '${theme.key} @ $scale',
            );
          },
        );
      }
    }
  });

  group('skeletons', () {
    testWidgets('NovaSkeleton and NovaSkeletonList render without error', (
      tester,
    ) async {
      await tester.pumpWidget(
        await _host(
          const Column(
            children: [
              NovaSkeleton(height: 40, width: 120),
              Expanded(child: NovaSkeletonList(count: 3, itemHeight: 60)),
            ],
          ),
        ),
      );
      await _pump(tester);
      expect(find.byType(NovaSkeleton), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('feedback helpers', () {
    testWidgets('NovaSnackbar.success shows a floating SnackBar', (
      tester,
    ) async {
      await tester.pumpWidget(
        await _host(
          Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => NovaSnackbar.success(context, 'Saved'),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Saved'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('novaConfirm returns true on confirm, false on cancel', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        await _host(
          Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );

      final f1 = novaConfirm(
        ctx,
        title: 'Delete?',
        message: 'Sure?',
        confirmLabel: 'Delete',
        cancelLabel: 'Cancel',
        destructive: true,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(await f1, isTrue);

      final f2 = novaConfirm(
        ctx,
        title: 'Delete?',
        message: 'Sure?',
        confirmLabel: 'Delete',
        cancelLabel: 'Cancel',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(await f2, isFalse);
    });
  });

  group('shared widgets', () {
    testWidgets('NovaSectionLabel uppercases its text', (tester) async {
      await tester.pumpWidget(
        await _host(const NovaSectionLabel('account details')),
      );
      await _pump(tester);
      expect(find.text('ACCOUNT DETAILS'), findsOneWidget);
    });

    testWidgets('NovaStickyBar keeps a bottom SafeArea for the gesture bar '
        '(§44)', (tester) async {
      await tester.pumpWidget(
        await _host(
          const Align(
            alignment: Alignment.bottomCenter,
            child: NovaStickyBar(child: Text('CTA')),
          ),
        ),
      );
      await _pump(tester);
      final safeArea = tester.widget<SafeArea>(
        find.descendant(
          of: find.byType(NovaStickyBar),
          matching: find.byType(SafeArea),
        ),
      );
      expect(safeArea.top, isFalse);
      expect(safeArea.bottom, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('cards survive large text', () {
    for (final scale in [1.0, 1.3]) {
      testWidgets('OrderCard: no overflow at 360px @ textScale $scale', (
        tester,
      ) async {
        final order = OrderListItemModel(
          id: 1,
          orderNumber: 'MK-2026-000123',
          status: OrderStatus.paid,
          total: '48200.00',
          currency: 'KZT',
          itemCount: 3,
          createdAt: DateTime(2026, 3, 4),
          itemsPreview: const [],
        );
        await tester.pumpWidget(
          await _host(
            OrderCard(order: order, onTap: () {}),
            textScale: scale,
            size: const Size(360, 800),
          ),
        );
        await _pump(tester);
        expect(
          tester.takeException(),
          isNull,
          reason: 'overflow @ textScale $scale',
        );
        expect(find.text('MK-2026-000123'), findsOneWidget);
      });
    }
  });
}
