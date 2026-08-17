import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnfp_wallet/gnfp_ledger.dart';
import 'package:gnfp_wallet/gnfp_pool_client.dart';
import 'package:gnfp_wallet/gnfp_session.dart';
import 'package:gnfp_wallet/gnfp_update.dart';
import 'package:gnfp_wallet/main.dart';
import 'package:gnfp_wallet/screens/wallet_screen.dart';

import 'pool_harness.dart';

const cpuPreWork = 'gnfp-wallet-seed';
const cpuNonce = '0000000000000006';

Future<void> settleCredit(WidgetTester tester, String expected) async {
  await tester.pump();
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    final text =
        tester.widget<Text>(find.byKey(const Key('gnfp-credit-status'))).data ??
            '';
    if (text == expected) return;
  }
}

String creditStatusText(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(const Key('gnfp-credit-status'))).data ??
      '';
}

void expectOnlyMinedPhrases(String text) {
  expect(
    text == gnfpCreditAdded || text == gnfpCreditNone,
    isTrue,
    reason: 'credit status must be one of the two mined-coins phrases, got: $text',
  );
  expect(text.contains('StateError'), isFalse);
  expect(text.contains('Exception'), isFalse);
  expect(text.contains('no miner book'), isFalse);
}

void main() {
  testWidgets(
    'credit control is on the facade and uses the two mined-coins phrases',
    (tester) async {
      HttpOverrides.global = RealHttpOverrides();
      addTearDown(() {
        HttpOverrides.global = null;
      });
      final pool = await tester.runAsync(startShippedPool);
      expect(pool, isNotNull);
      addTearDown(() async {
        await tester.runAsync(pool!.stop);
      });

      final http = HttpClient();
      addTearDown(() => http.close(force: true));
      final miner = GnfpLedger(
        pool: GnfpPoolClient(baseUrl: pool!.uri.toString(), http: http),
      );
      final wallet = GnfpLedger(
        pool: GnfpPoolClient(baseUrl: pool.uri.toString(), http: http),
      );
      const seed = 'credit-facade-seed';
      final addr = miner.createAddress(seed: seed);
      wallet.adopt(addr);

      final store = File(
        '${Directory.systemTemp.path}/gnfp-widget-session-credit.json',
      );
      store.writeAsStringSync(
        jsonEncode({'seed': seed, 'address': addr.value, 'schema': 2}),
      );
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        GnfpWalletApp(
          ledger: wallet,
          version: '0.0.5',
          session: GnfpSession(store: store),
          updateCheck: GnfpUpdateCheck(fetchJson: (_) async => null),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('gnfp-credit-miner')));
      expect(find.byKey(const Key('gnfp-credit-miner')), findsOneWidget);
      expect(find.byKey(const Key('gnfp-credit-status')), findsOneWidget);

      // Empty book: creditFromMiner throws; UI must not dump the error.
      await tester.tap(find.byKey(const Key('gnfp-credit-miner')));
      await settleCredit(tester, gnfpCreditNone);
      expect(creditStatusText(tester), gnfpCreditNone);
      expectOnlyMinedPhrases(creditStatusText(tester));

      // Mine on a separate ledger so the wallet local book is still empty.
      await tester.runAsync(() {
        return miner.miningReceive(
          to: addr,
          amount: 5,
          nonce: cpuNonce,
          solution: '',
          preWork: cpuPreWork,
        );
      });
      await tester.tap(find.byKey(const Key('gnfp-credit-miner')));
      await settleCredit(tester, gnfpCreditAdded);
      expect(creditStatusText(tester), gnfpCreditAdded);
      expectOnlyMinedPhrases(creditStatusText(tester));

      // Second tap: live book already in the wallet, amount == 0.
      await tester.tap(find.byKey(const Key('gnfp-credit-miner')));
      await settleCredit(tester, gnfpCreditNone);
      expectOnlyMinedPhrases(creditStatusText(tester));

      await tester.pumpWidget(const SizedBox.shrink());
      http.close(force: true);
      await tester.pump();
    },
  );
}
