import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_marketplace/core/api/api_client.dart';
import 'package:nova_marketplace/core/api/token_refresher.dart';
import 'package:nova_marketplace/core/auth/token_store.dart';
import 'package:nova_marketplace/core/errors/api_exception.dart';
import 'package:nova_marketplace/features/seller/dashboard/application/seller_dashboard_controller.dart';
import 'package:nova_marketplace/features/seller/finance/application/seller_finance_controller.dart';
import 'package:nova_marketplace/features/seller/finance/data/seller_finance_repository.dart';
import 'package:nova_marketplace/features/seller/payouts/application/payout_request_controller.dart';
import 'package:nova_marketplace/features/seller/payouts/application/seller_payouts_controller.dart';
import 'package:nova_marketplace/features/seller/payouts/data/seller_payout_models.dart';
import 'package:nova_marketplace/features/seller/payouts/data/seller_payout_repository.dart';

import 'support/f4_harness.dart';
import 'support/f6a_fixtures.dart';
import 'support/f6d_fixtures.dart';
import 'support/fake_auth_repository.dart';
import 'support/fake_dio.dart';
import 'support/test_harness.dart';

ApiClient _client(FakeAdapter a) => ApiClient(
  tokenStore: TokenStore(FakeSecureStore()),
  tokenRefresher: const NoopTokenRefresher(),
  dio: Dio()..httpClientAdapter = a,
);

Future<F4Container> _seller(MeBackend be) async {
  final h = await F4Container.create(
    backend: be,
    user: fakeUser(role: 'seller', sellerId: 1),
  );
  h.container
    ..listen(sellerFinanceControllerProvider, (_, _) {})
    ..listen(sellerPayoutsControllerProvider, (_, _) {})
    ..listen(payoutRequestControllerProvider, (_, _) {})
    ..listen(sellerDashboardControllerProvider, (_, _) {});
  await h.settleAuth();
  await h.login();
  return h;
}

MeBackend _backend({
  String available = '2626800.00',
  ResponseBody Function(RequestOptions o)? createPayout,
  List<Map<String, dynamic>>? payouts,
}) => MeBackend()
  ..on(
    'GET /seller/finance',
    (o) => ok(sellerFinanceJson(availableBalance: available)),
  )
  ..on(
    'GET /seller/payouts',
    (o) => okRaw(payouts ?? [sellerPayoutJson(id: 1, status: 'paid')]),
  )
  ..on(
    'POST /seller/payouts',
    createPayout ??
        (o) => jsonBody(201, {
          'data': sellerPayoutJson(id: 900, amount: '100.00'),
        }),
  )
  ..on('GET /seller/dashboard', (o) => ok(sellerDashboardJson()))
  ..on('GET /sellers/1', (o) => ok(sellerProfileJson()));

void main() {
  group('SellerFinanceRepository', () {
    test('parses the exact backend field set (exact strings)', () async {
      final adapter = FakeAdapter(
        (o, i) => ok(
          sellerFinanceJson(
            grossSales: '8118752.00',
            commissionTotal: '811875.20',
            sellerNetTotal: '7306876.80',
            pendingBalance: '4678876.80',
            availableBalance: '2626800.00',
            paidOutTotal: '51200.00',
          ),
        ),
      );
      final m = await SellerFinanceRepository(_client(adapter)).getSummary();
      expect(m.grossSales, '8118752.00');
      expect(m.commissionTotal, '811875.20');
      expect(m.sellerNetTotal, '7306876.80');
      expect(m.pendingBalance, '4678876.80');
      expect(m.availableBalance, '2626800.00');
      expect(m.paidOutTotal, '51200.00');
      expect(adapter.received.single.path, endsWith('/seller/finance'));
    });
  });

  group('SellerPayoutRepository', () {
    test('list parses rows incl. nullable processed_at', () async {
      final adapter = FakeAdapter(
        (o, i) => okRaw([
          sellerPayoutJson(id: 2, status: 'pending'),
          sellerPayoutJson(
            id: 1,
            status: 'paid',
            processedAt: '2026-08-31T00:00:06.047923+05:00',
          ),
        ]),
      );
      final list = await SellerPayoutRepository(_client(adapter)).list();
      expect(list.map((p) => p.id), [2, 1]);
      expect(list.first.status, PayoutStatus.pending);
      expect(list.first.processedAt, isNull);
      expect(list[1].processedAt, isNotNull);
    });

    test(
      'create posts {amount} + Idempotency-Key header, no bank fields',
      () async {
        late RequestOptions req;
        final adapter = FakeAdapter((o, i) {
          req = o;
          return jsonBody(201, {'data': sellerPayoutJson(id: 5)});
        });
        final r = await SellerPayoutRepository(
          _client(adapter),
        ).create(amount: '1000.00', idempotencyKey: 'k-1');
        expect(r.payout.id, 5);
        final body = Map<String, dynamic>.from(req.data as Map);
        expect(body.keys.toSet(), {'amount'});
        expect(body['amount'], '1000.00');
        expect(req.headers['Idempotency-Key'], 'k-1');
        for (final banned in ['iban', 'card', 'account', 'bank']) {
          expect(body.containsKey(banned), isFalse);
        }
      },
    );

    test(
      'INSUFFICIENT_AVAILABLE_BALANCE surfaces as ApiException(conflict)',
      () async {
        final adapter = FakeAdapter(
          (o, i) => jsonBody(409, {
            'error': {
              'code': 'INSUFFICIENT_AVAILABLE_BALANCE',
              'message': 'Available balance is only 5.00',
            },
          }),
        );
        await expectLater(
          SellerPayoutRepository(
            _client(adapter),
          ).create(amount: '999999.00', idempotencyKey: 'k'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.kind, 'kind', ApiErrorKind.conflict)
                .having(
                  (e) => e.code,
                  'code',
                  'INSUFFICIENT_AVAILABLE_BALANCE',
                ),
          ),
        );
      },
    );
  });

  group('finance + payouts controllers', () {
    test('finance loads; error then refresh recovers', () async {
      var fail = true;
      final be = MeBackend()
        ..on(
          'GET /seller/finance',
          (o) => fail
              ? jsonBody(503, {
                  'error': {'code': 'X', 'message': 'down'},
                })
              : ok(sellerFinanceJson()),
        )
        ..on('GET /seller/payouts', (o) => okRaw(const []))
        ..on('GET /seller/dashboard', (o) => ok(sellerDashboardJson()))
        ..on('GET /sellers/1', (o) => ok(sellerProfileJson()));
      final h = await _seller(be);
      await pumpUntil(
        () =>
            h.container.read(sellerFinanceControllerProvider).status ==
            SellerFinanceStatus.error,
      );
      fail = false;
      await h.container
          .read(sellerFinanceControllerProvider.notifier)
          .refresh();
      final st = h.container.read(sellerFinanceControllerProvider);
      expect(st.status, SellerFinanceStatus.loaded);
      expect(st.data!.availableBalance, '2626800.00');
    });

    test('empty payout history → isEmpty', () async {
      final h = await _seller(_backend(payouts: const []));
      await pumpUntil(
        () =>
            h.container.read(sellerPayoutsControllerProvider).status ==
            SellerPayoutsStatus.loaded,
      );
      expect(h.container.read(sellerPayoutsControllerProvider).isEmpty, isTrue);
    });
  });

  group('PayoutRequestController', () {
    test(
      'idempotency key is stable across reads; new only on new attempt',
      () async {
        final h = await _seller(_backend());
        final n = h.container.read(payoutRequestControllerProvider.notifier);
        final k0 = h.container
            .read(payoutRequestControllerProvider)
            .idempotencyKey;
        expect(k0, isNotEmpty);
        // reading again (rebuild) keeps the key
        expect(
          h.container.read(payoutRequestControllerProvider).idempotencyKey,
          k0,
        );
        n.startNewAttempt();
        expect(
          h.container.read(payoutRequestControllerProvider).idempotencyKey,
          isNot(k0),
        );
      },
    );

    test('submit success → phase success, refreshes payouts + finance + '
        'invalidates dashboard', () async {
      var payouts = <Map<String, dynamic>>[sellerPayoutJson(id: 1)];
      var available = '2626800.00';
      final be = MeBackend()
        ..on(
          'GET /seller/finance',
          (o) => ok(sellerFinanceJson(availableBalance: available)),
        )
        ..on('GET /seller/payouts', (o) => okRaw(payouts))
        ..on('POST /seller/payouts', (o) {
          available = '2626700.00';
          payouts = [
            sellerPayoutJson(id: 2, amount: '100.00'),
            sellerPayoutJson(id: 1),
          ];
          return jsonBody(201, {
            'data': sellerPayoutJson(id: 2, amount: '100.00'),
          });
        })
        ..on('GET /seller/dashboard', (o) => ok(sellerDashboardJson()))
        ..on('GET /sellers/1', (o) => ok(sellerProfileJson()));
      final h = await _seller(be);
      await pumpUntil(
        () =>
            h.container.read(sellerPayoutsControllerProvider).status ==
            SellerPayoutsStatus.loaded,
      );

      await h.container
          .read(payoutRequestControllerProvider.notifier)
          .submit('100.00');

      final rq = h.container.read(payoutRequestControllerProvider);
      expect(rq.phase, PayoutRequestPhase.success);
      expect(rq.result!.payout.id, 2);
      await pumpUntil(
        () =>
            h.container.read(sellerPayoutsControllerProvider).items.length == 2,
      );
      expect(
        h.container
            .read(sellerFinanceControllerProvider)
            .data!
            .availableBalance,
        '2626700.00',
      );
      expect(be.countOf('POST', '/seller/payouts'), 1);
    });

    test('double submit fires only one POST (§11)', () async {
      var posts = 0;
      final be = _backend(
        createPayout: (o) {
          posts++;
          return jsonBody(201, {'data': sellerPayoutJson(id: 9)});
        },
      );
      final h = await _seller(be);
      await pumpUntil(
        () =>
            h.container.read(sellerFinanceControllerProvider).status ==
            SellerFinanceStatus.loaded,
      );
      final n = h.container.read(payoutRequestControllerProvider.notifier);
      await Future.wait([
        n.submit('50.00'),
        n.submit('50.00'),
        n.submit('50.00'),
      ]);
      expect(posts, 1);
    });

    test('retry after failure reuses the SAME idempotency key (§15)', () async {
      final keys = <String?>[];
      var fail = true;
      final be = _backend(
        createPayout: (o) {
          keys.add(o.headers['Idempotency-Key'] as String?);
          if (fail) {
            fail = false;
            return jsonBody(500, {
              'error': {'code': 'INTERNAL_ERROR', 'message': 'x'},
            });
          }
          return jsonBody(201, {'data': sellerPayoutJson(id: 3)});
        },
      );
      final h = await _seller(be);
      await pumpUntil(
        () =>
            h.container.read(sellerFinanceControllerProvider).status ==
            SellerFinanceStatus.loaded,
      );
      final n = h.container.read(payoutRequestControllerProvider.notifier);
      await n.submit('100.00');
      expect(
        h.container.read(payoutRequestControllerProvider).phase,
        PayoutRequestPhase.error,
      );
      await n.retry('100.00');
      expect(
        h.container.read(payoutRequestControllerProvider).phase,
        PayoutRequestPhase.success,
      );
      expect(keys, hasLength(2));
      expect(keys[0], keys[1]);
    });

    test('backend insufficient balance → error state, key kept', () async {
      final be = _backend(
        createPayout: (o) => jsonBody(409, {
          'error': {'code': 'INSUFFICIENT_AVAILABLE_BALANCE', 'message': 'no'},
        }),
      );
      final h = await _seller(be);
      await pumpUntil(
        () =>
            h.container.read(sellerFinanceControllerProvider).status ==
            SellerFinanceStatus.loaded,
      );
      final n = h.container.read(payoutRequestControllerProvider.notifier);
      final keyBefore = h.container
          .read(payoutRequestControllerProvider)
          .idempotencyKey;
      await n.submit('999999.00');
      final rq = h.container.read(payoutRequestControllerProvider);
      expect(rq.phase, PayoutRequestPhase.error);
      expect(rq.errorCode, 'INSUFFICIENT_AVAILABLE_BALANCE');
      expect(rq.idempotencyKey, keyBefore);
    });
  });
}
