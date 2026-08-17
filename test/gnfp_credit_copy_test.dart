import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gnfp_wallet/gnfp_ledger.dart';
import 'package:gnfp_wallet/gnfp_pool_client.dart';
import 'package:gnfp_wallet/screens/wallet_screen.dart';

import 'pool_harness.dart';

void main() {
  PoolHandle? pool;

  setUpAll(() async {
    HttpOverrides.global = RealHttpOverrides();
    pool = await startShippedPool();
  });

  tearDownAll(() async {
    await pool?.stop();
  });

  GnfpLedger liveLedger() =>
      GnfpLedger(pool: GnfpPoolClient(baseUrl: pool!.uri.toString()));

  test('creditWalletPhrase is only the two mined-coins lines', () {
    expect(creditWalletPhrase(added: true), gnfpCreditAdded);
    expect(creditWalletPhrase(added: false), gnfpCreditNone);
    expect(creditWalletPhrase(added: true).contains('StateError'), isFalse);
    expect(creditWalletPhrase(added: false).contains('Exception'), isFalse);
  });

  test('empty miner book and second credit map to no mined coins phrase', () async {
    final miner = liveLedger();
    final wallet = liveLedger();
    final a = miner.createAddress(seed: 'credit-none');
    Object? err;
    try {
      await wallet.creditFromMiner(to: a);
    } catch (e) {
      err = e;
    }
    expect(err, isNotNull);
    expect(creditWalletPhrase(added: false), gnfpCreditNone);

    await miner.miningReceive(
      to: a,
      amount: 5,
      nonce: '0000000000000006',
      solution: '',
      preWork: 'gnfp-wallet-seed',
    );
    wallet.adopt(a);
    final added = await wallet.creditFromMiner(to: a);
    expect(creditWalletPhrase(added: added.amount > 0), gnfpCreditAdded);
    final again = await wallet.creditFromMiner(to: a);
    expect(creditWalletPhrase(added: again.amount > 0), gnfpCreditNone);
  });
}
