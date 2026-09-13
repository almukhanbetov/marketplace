import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_marketplace/core/auth/auth_controller.dart';
import 'package:nova_marketplace/core/auth/auth_repository.dart';
import 'package:nova_marketplace/core/auth/auth_repository_impl.dart';
import 'package:nova_marketplace/core/auth/auth_state.dart';
import 'package:nova_marketplace/core/storage/secure_storage.dart';

import 'support/fake_auth_repository.dart';
import 'support/test_harness.dart';

ProviderContainer build(FakeAuthRepository repo, {FakeSecureStore? store}) {
  final c = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      secureStoreProvider.overrideWithValue(store ?? FakeSecureStore()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> settle(ProviderContainer c) async {
  for (var i = 0; i < 100; i++) {
    final st = c.read(authControllerProvider).status;
    if (st != AuthStatus.unknown && st != AuthStatus.restoring) return;
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

void main() {
  group('restoreSession', () {
    test('no stored refresh token → unauthenticated', () async {
      final c = build(FakeAuthRepository());
      await settle(c);
      expect(c.read(authControllerProvider).status, AuthStatus.unauthenticated);
    });

    test('valid stored token → refresh + me → authenticated', () async {
      final repo = FakeAuthRepository(
        onRefresh: () async => fakeTokens(access: 'fresh', refresh: 'rot'),
        onMe: () async => fakeUser(role: 'customer', name: 'Restored'),
      );
      final c = build(repo, store: FakeSecureStore(refreshToken: 'stored'));
      await settle(c);
      final st = c.read(authControllerProvider);
      expect(st.status, AuthStatus.authenticated);
      expect(st.user?.fullName, 'Restored');
      expect(repo.refreshCalls, 1);
    });

    test('invalid stored token → unauthenticated, no transient flag', () async {
      final repo = FakeAuthRepository(onRefresh: () async => null);
      final c = build(repo, store: FakeSecureStore(refreshToken: 'dead'));
      await settle(c);
      final st = c.read(authControllerProvider);
      expect(st.status, AuthStatus.unauthenticated);
      expect(st.restoreFailedTransiently, isFalse);
    });

    test(
      'transient failure → unauthenticated + transient flag + token kept',
      () async {
        final store = FakeSecureStore(refreshToken: 'stored');
        final repo = FakeAuthRepository(onRefresh: () async => throw offline());
        final c = build(repo, store: store);
        await settle(c);
        final st = c.read(authControllerProvider);
        expect(st.status, AuthStatus.unauthenticated);
        expect(st.restoreFailedTransiently, isTrue);
        expect(await store.readRefreshToken(), 'stored'); // NOT cleared
      },
    );

    test('retryRestore recovers after a transient failure', () async {
      final store = FakeSecureStore(refreshToken: 'stored');
      var fail = true;
      final repo = FakeAuthRepository(
        onRefresh: () async {
          if (fail) throw offline();
          return fakeTokens();
        },
        onMe: () async => fakeUser(),
      );
      final c = build(repo, store: store);
      await settle(c);
      expect(c.read(authControllerProvider).restoreFailedTransiently, isTrue);

      fail = false;
      await c.read(authControllerProvider.notifier).retryRestore();
      expect(c.read(authControllerProvider).status, AuthStatus.authenticated);
    });
  });

  test('login success → authenticated + role returned', () async {
    final repo = FakeAuthRepository(
      onLogin: (_) async => AuthSession(
        tokens: fakeTokens(),
        user: fakeUser(role: 'seller', sellerId: 3),
      ),
    );
    final c = build(repo);
    await settle(c);
    final role = await c
        .read(authControllerProvider.notifier)
        .login(identifier: 'x@y.z', password: 'pw');
    expect(role, AuthUserRole.seller);
    expect(c.read(authControllerProvider).status, AuthStatus.authenticated);
  });

  test('login failure → throws; state stays unauthenticated', () async {
    final repo = FakeAuthRepository(onLogin: (_) async => throw unauthorized());
    final c = build(repo);
    await settle(c);
    await expectLater(
      c
          .read(authControllerProvider.notifier)
          .login(identifier: 'x@y.z', password: 'bad'),
      throwsA(isA<Object>()),
    );
    expect(c.read(authControllerProvider).status, AuthStatus.unauthenticated);
  });

  test('register success → authenticated (customer)', () async {
    final repo = FakeAuthRepository(
      onRegister: (_) async =>
          AuthSession(tokens: fakeTokens(), user: fakeUser()),
    );
    final c = build(repo);
    await settle(c);
    final role = await c
        .read(authControllerProvider.notifier)
        .register(fullName: 'A B', email: 'a@b.c', password: 'passw0rd');
    expect(role, AuthUserRole.customer);
    expect(c.read(authControllerProvider).status, AuthStatus.authenticated);
  });

  test('logout → unauthenticated, repo.logout invoked', () async {
    final repo = FakeAuthRepository(
      onLogin: (_) async => AuthSession(tokens: fakeTokens(), user: fakeUser()),
    );
    final c = build(repo);
    await settle(c);
    await c
        .read(authControllerProvider.notifier)
        .login(identifier: 'x@y.z', password: 'pw');
    await c.read(authControllerProvider.notifier).logout();
    expect(repo.logoutCalls, 1);
    expect(c.read(authControllerProvider).status, AuthStatus.unauthenticated);
  });

  test('forceLoggedOut flips to unauthenticated', () async {
    final c = build(FakeAuthRepository());
    await settle(c);
    c.read(authControllerProvider.notifier).forceLoggedOut();
    expect(c.read(authControllerProvider).status, AuthStatus.unauthenticated);
  });
}
