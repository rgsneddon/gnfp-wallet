import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gnfp_wallet/gnfp_ledger.dart';
import 'package:gnfp_wallet/gnfp_owner_ledger.dart';
import 'package:gnfp_wallet/gnfp_pool_client.dart';
import 'package:gnfp_wallet/gnfp_cpu_hash.dart';
import 'package:gnfp_wallet/gnfp_session.dart';

import 'pool_harness.dart';

var _cpuSeed = 0;

Future<GnfpTx> seedMinerBook(
  GnfpLedger ledger,
  GnfpAddress to,
  double amount,
) {
  _cpuSeed += 1;
  final preWork = 'gnfp-wallet-seed-persist-$_cpuSeed';
  var nonce = '0000000000000001';
  for (var i = 1; i < 400000; i += 1) {
    final tryNonce = nextCpuNonce(i);
    if (hashMeetsJob({'input': preWork, 'difficulty': 14}, tryNonce)) {
      nonce = tryNonce;
      break;
    }
  }
  return ledger.miningReceive(
    to: to,
    amount: amount,
    nonce: nonce,
    solution: '',
    preWork: preWork,
  );
}

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

  test('Android store path is the app-private files dir, not cwd/.gnfp', () {
    final path = GnfpSession.androidDefaultStorePath();
    expect(path, '/data/user/0/online.restoreprivacy.gnfp_wallet/files/GNFP/session.json');
    expect(path.contains('/.gnfp/'), isFalse);
    final legacy = GnfpSession.defaultLegacyStores(home: '/data')
        .map((f) => f.path);
    expect(
      legacy,
      contains('/data/user/0/online.restoreprivacy.gnfp_wallet/files/GNFP/session.json'),
    );
  });

  test('close/reopen of shipped session keeps gnfp1 and last-known spendable', () async {
    final dir = await Directory.systemTemp.createTemp('gnfp-reopen');
    final store = File('${dir.path}/session.json');
    final firstLedger = liveLedger();
    final first = GnfpSession(store: store);
    final addr = await first.ensureAddress(firstLedger);
    final seeded = await seedMinerBook(firstLedger, addr, 88);
    expect(firstLedger.balance(addr), seeded.amount);
    first.rememberSpendable(addr, firstLedger.balance(addr));
    await first.persist();

    final raw = jsonDecode(store.readAsStringSync()) as Map;
    expect(raw['address'], addr.value);
    expect(raw['spendable'], isA<Map>());

    final againLedger = liveLedger();
    final again = GnfpSession(store: store);
    final loaded = await again.load(againLedger);
    expect(loaded!.value, addr.value);
    final cached = again.lastKnownSpendable(loaded);
    expect(cached, seeded.amount);
    againLedger.rememberSpendable(loaded, cached);
    expect(againLedger.balance(loaded), seeded.amount);

    againLedger.rememberSpendable(loaded, 88);
    final wiped = await againLedger.syncSpendable(loaded);
    expect(wiped, greaterThan(0));
    expect(wiped, seeded.amount);
  });

  test('Android-shaped store close/reopen does not mint a new gnfp1 or wipe spendable', () async {
    final dir = await Directory.systemTemp.createTemp('gnfp-android-store');
    final store = File(
      '${dir.path}/data/user/0/online.restoreprivacy.gnfp_wallet/files/GNFP/session.json',
    );
    store.parent.createSync(recursive: true);
    final ledger = liveLedger();
    final session = GnfpSession(store: store);
    final addr = await session.ensureAddress(ledger);
    await seedMinerBook(ledger, addr, 42);
    session.rememberSpendable(addr, ledger.balance(addr));
    await session.persist();

    final reopenedLedger = GnfpLedger(pool: ledger.pool);
    final reopened = GnfpSession(store: store);
    final same = await reopened.ensureAddress(reopenedLedger);
    expect(same.value, addr.value);
    reopenedLedger.rememberSpendable(same, reopened.lastKnownSpendable(same));
    expect(reopenedLedger.balance(same), ledger.balance(addr));
    final live = await reopenedLedger.syncSpendable(same);
    expect(live, ledger.balance(addr));
  });

  test('reconstructSpendable uses address PLUS shear and matches the book amount', () async {
    final ledger = liveLedger();
    final a = ledger.createAddress(seed: 'reconstruct-owner');
    final b = ledger.createAddress(seed: 'reconstruct-peer');
    final seeded = await seedMinerBook(ledger, a, 20);
    final sendAmt = seeded.amount / 2;
    await ledger.send(from: a, to: b, amount: sendAmt);
    final hist = await ledger.pool.history(a.value);
    final txs = (hist['txs'] as List?) ?? const [];
    expect(txs, isNotEmpty);
    final rec = reconstructSpendable(
      address: a.value,
      shear: '',
      txs: txs,
    );
    expect(rec, closeTo(seeded.amount - sendAmt, 1e-18));
    expect(await ledger.pool.balance(a.value), closeTo(rec, 1e-18));
    expect(
      reconstructSpendable(address: a.value, shear: 'shear-deadbeef', txs: txs),
      0,
    );
  });

  test('live zero does not replace a known spendable on a fresh ledger+session', () async {
    final dir = await Directory.systemTemp.createTemp('gnfp-keep-zero');
    final store = File('${dir.path}/session.json');
    final session = GnfpSession(store: store);
    final addr = GnfpAddress('gnfp1dddddddddddddddddddddddddddddddddddddddd');
    session.address = addr;
    session.seed = 'keep-zero';
    session.rememberSpendable(addr, 777);
    await session.persist();

    final fresh = GnfpSession(store: store);
    final dead = GnfpLedger(pool: GnfpPoolClient(baseUrl: 'http://127.0.0.1:1'));
    final loaded = await fresh.load(dead);
    expect(loaded!.value, addr.value);
    dead.rememberSpendable(loaded, fresh.lastKnownSpendable(loaded));
    expect(dead.balance(loaded), 777);
    final kept = await dead.syncSpendable(loaded);
    expect(kept, 777);
  });
}
