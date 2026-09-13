import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nova_marketplace/app/app.dart';
import 'package:nova_marketplace/core/auth/auth_repository.dart';

import 'support/fake_auth_repository.dart';
import 'support/test_harness.dart';

/// A repo that "restores" into a given role, or into logged-out.
FakeAuthRepository repoForRole(String? role, {int? sellerId}) {
  if (role == null) return FakeAuthRepository();
  return FakeAuthRepository(
    onRefresh: () async => fakeTokens(),
    onMe: () async => fakeUser(role: role, sellerId: sellerId),
    onLogin: (_) async => AuthSession(
      tokens: fakeTokens(),
      user: fakeUser(role: role, sellerId: sellerId),
    ),
  );
}

Future<void> pumpApp(
  WidgetTester tester, {
  FakeAuthRepository? repo,
  bool withToken = false,
}) async {
  await tester.pumpWidget(
    await wrapForTest(
      const NovaApp(),
      authRepo: repo ?? FakeAuthRepository(),
      secureStore: FakeSecureStore(refreshToken: withToken ? 'stored' : null),
    ),
  );
  await tester.pumpAndSettle();
}

BuildContext _ctx(WidgetTester tester) =>
    tester.element(find.byType(Navigator).first);

void main() {
  testWidgets('anonymous lands on the home shell', (tester) async {
    await pumpApp(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('anonymous → /profile redirects to login', (tester) async {
    await pumpApp(tester);
    _ctx(tester).go('/profile');
    await tester.pumpAndSettle();
    expect(find.text('Вход'), findsWidgets); // login screen title (RU default)
  });

  testWidgets('anonymous → /seller/dashboard redirects to login', (
    tester,
  ) async {
    await pumpApp(tester);
    _ctx(tester).go('/seller/dashboard');
    await tester.pumpAndSettle();
    expect(find.text('Вход'), findsWidgets);
  });

  testWidgets('customer → /seller/dashboard shows the sellers-only screen', (
    tester,
  ) async {
    await pumpApp(tester, repo: repoForRole('customer'), withToken: true);
    _ctx(tester).go('/seller/dashboard');
    await tester.pumpAndSettle();
    expect(find.text('Только для продавцов'), findsOneWidget);
  });

  testWidgets('seller → /seller/dashboard is allowed', (tester) async {
    await pumpApp(
      tester,
      repo: repoForRole('seller', sellerId: 3),
      withToken: true,
    );
    _ctx(tester).go('/seller/dashboard');
    await tester.pumpAndSettle();
    // The F6 placeholder badge is visible; the forbidden screen is not.
    expect(find.text('Только для продавцов'), findsNothing);
  });

  testWidgets('authenticated → /login redirects away to home', (tester) async {
    await pumpApp(tester, repo: repoForRole('customer'), withToken: true);
    _ctx(tester).go('/login');
    await tester.pumpAndSettle();
    expect(find.text('Вход'), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('admin → /admin shows the web-only notice', (tester) async {
    await pumpApp(tester, repo: repoForRole('admin'), withToken: true);
    _ctx(tester).go('/admin');
    await tester.pumpAndSettle();
    expect(find.text('Администрирование в веб-версии'), findsOneWidget);
  });

  testWidgets('admin landing in the customer shell is bounced to the notice', (
    tester,
  ) async {
    await pumpApp(tester, repo: repoForRole('admin'), withToken: true);
    _ctx(tester).go('/catalog');
    await tester.pumpAndSettle();
    expect(find.text('Администрирование в веб-версии'), findsOneWidget);
  });
}
