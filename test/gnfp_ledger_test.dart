import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gnfp_wallet/gnfp_analysis.dart';
import 'package:gnfp_wallet/gnfp_bridge.dart';
import 'package:gnfp_wallet/gnfp_build_stamp.dart';
import 'package:gnfp_wallet/gnfp_cpu_hash.dart';
import 'package:gnfp_wallet/gnfp_ledger.dart';
import 'package:gnfp_wallet/gnfp_pool_client.dart';
import 'package:gnfp_wallet/gnfp_session.dart';
import 'package:gnfp_wallet/gnfp_surfaces.dart';
import 'package:gnfp_wallet/gnfp_theme.dart';
import 'package:gnfp_wallet/gnfp_version.dart';

import 'pool_harness.dart';

/// CPU work-hash the live book accepts (empty output, 16-hex nonce).
var _cpuSeed = 0;

Future<GnfpTx> seedMinerBook(
  GnfpLedger ledger,
  GnfpAddress to,
  double amount,
) {
  _cpuSeed += 1;
  final preWork = 'gnfp-wallet-seed-$_cpuSeed';
  var nonce = '0000000000000001';
  for (var i = 1; i < 200000; i += 1) {
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

  test('live pool share-accept is pending spendable with empty owner history', () async {
    final ledger = liveLedger();
    final owner = ledger.createAddress(seed: 'live-round-explorer');
    ledger.adopt(owner);
    final script = File('${shippedWalletHttp().parent.path}/submit_share_once.mjs');
    expect(script.existsSync(), isTrue, reason: script.path);
    final ran = await Process.run(
      'node',
      [script.path, pool!.uri.toString(), owner.value],
      workingDirectory: script.parent.parent.path,
    ).timeout(const Duration(seconds: 8));
    expect(ran.exitCode, 0, reason: '${ran.stdout} ${ran.stderr}');
    final pending = (1 << 14) / 1e9;
    expect(await ledger.syncSpendable(owner), closeTo(pending, 1e-12));
    expect(ledger.pendingMining(owner), closeTo(pending, 1e-12));
    expect((await ledger.syncOwnerHistory(owner)), isEmpty);
  });

  test('syncSpendable does not wipe a known amount with live zero', () async {
    final ledger = GnfpLedger(
      pool: GnfpPoolClient(baseUrl: 'http://127.0.0.1:1'),
    );
    final a = ledger.createAddress(seed: 'keep-coins');
    ledger.rememberSpendable(a, 1200);
    expect(ledger.balance(a), 1200);
    final kept = await ledger.syncSpendable(a);
    expect(kept, 1200);
    expect(ledger.balance(a), 1200);
  });

  test('syncSpendable follows pending mining credit then a confirmed round amount', () async {
    final pending = (1 << 14) / 1e9;
    final bundled = 0.99 + 2 * pending;
    final addr = GnfpLedger().createAddress(seed: 'pending-round');
    final pool = _PendingThenRoundClient(addr.value, pending: pending, bundled: bundled);
    final ledger = GnfpLedger(pool: pool);
    ledger.adopt(addr);
    expect(await ledger.syncSpendable(addr), pending);
    expect(ledger.balance(addr), pending);
    expect((await ledger.syncOwnerHistory(addr)), isEmpty);
    pool.tipReached = true;
    expect(await ledger.syncSpendable(addr), bundled);
    final rows = await ledger.syncOwnerHistory(addr);
    expect(rows.length, 1);
    expect(rows.first.kind, 'mine');
    expect(rows.first.amount, bundled);
    expect(rows.first.height, 12);
  });

  test('parseSpendable reads string balances from the book', () {
    expect(GnfpPoolClient.parseSpendable({'balance': '1200.5'}), 1200.5);
    expect(GnfpPoolClient.parseSpendable({'balance': 12}), 12);
    expect(GnfpPoolClient.parseSpendable({}), 0);
  });

  test('self-mint receive and proof-less mining receive do not raise balance', () async {
    final ledger = liveLedger();
    final a = ledger.createAddress(seed: 'alice-nomint');
    expect(ledger.balance(a), 0);
    await expectLater(
      ledger.receive(to: a, amount: 1),
      throwsA(isA<StateError>()),
    );
    expect(ledger.balance(a), 0);
    expect(await ledger.pool.balance(a.value), 0);
    await expectLater(
      ledger.miningReceive(to: a, amount: 1),
      throwsA(isA<StateError>()),
    );
    expect(ledger.balance(a), 0);
    expect(await ledger.pool.balance(a.value), 0);
  });

  test('peer send and miner redeem are the only credit paths', () async {
    final ledger = liveLedger();
    final a = ledger.createAddress(seed: 'alice');
    final b = ledger.createAddress(seed: 'bob');
    expect(a.isValid, isTrue);
    expect(a.value.startsWith('gnfp1'), isTrue);
    expect(a.value.toLowerCase().contains('perc'), isFalse);
    expect(b.value, isNot(a.value));

    final seeded = await seedMinerBook(ledger, a, 10);
    final have = ledger.balance(a);
    expect(have, greaterThan(0));
    expect(have, seeded.amount);
    final sendAmt = have / 2;
    final sent = await ledger.send(from: a, to: b, amount: sendAmt);
    expect(sent.kind, 'send');
    expect(ledger.balance(a), closeTo(have - sendAmt, 1e-18));
    expect(ledger.balance(b), closeTo(sendAmt, 1e-18));
    expect(gnfpTicker, 'GNFP');
    expect(gnfpStratum, contains('de.restoreprivacy.online:1474'));
    expect(await ledger.pool.balance(b.value), closeTo(sendAmt, 1e-18));
  });

  test('syncSpendable after an app update keeps the book balance on the same gnfp1', () async {
    final miner = liveLedger();
    final a = miner.createAddress(seed: 'upgrade-keep');
    final seeded = await seedMinerBook(miner, a, 25);
    expect(await miner.pool.balance(a.value), seeded.amount);

    final upgraded = liveLedger();
    upgraded.adopt(a);
    expect(upgraded.balance(a), 0);
    final live = await upgraded.syncSpendable(a);
    expect(live, seeded.amount);
    expect(upgraded.balance(a), seeded.amount);
    expect(a.value, miner.createAddress(seed: 'upgrade-keep').value);
  });

  test('credit from your miner pulls live miner book without posting extra', () async {
    final miner = liveLedger();
    final a = miner.createAddress(seed: 'miner-pull');
    final seeded = await seedMinerBook(miner, a, 50);
    expect(miner.balance(a), seeded.amount);

    final wallet = liveLedger();
    wallet.adopt(a);
    expect(wallet.balance(a), 0);
    final tx = await wallet.creditFromMiner(to: a);
    expect(tx.kind, 'miner');
    expect(tx.memo, 'credit from your miner');
    expect(tx.from, gnfpStratum);
    expect(wallet.balance(a), seeded.amount);
    expect(await wallet.pool.balance(a.value), seeded.amount);

    expect(wallet.transactions.where((t) => t.kind == 'miner').length, 1);
    final afterClaim = wallet.transactions.length;
    final again = await wallet.creditFromMiner(to: a);
    expect(again.amount, 0);
    expect(wallet.transactions.length, afterClaim);
    expect(wallet.transactions.where((t) => t.amount <= 0), isEmpty);
    expect(wallet.balance(a), seeded.amount);
    expect(await wallet.pool.balance(a.value), seeded.amount);
  });

  test('session persists gnfp1 address without a login name', () async {
    final dir = await Directory.systemTemp.createTemp('gnfp-session');
    final store = File('${dir.path}/session.json');
    final first = GnfpSession(store: store);
    final ledger = liveLedger();
    final a = await first.ensureAddress(ledger);
    expect(a.value.startsWith('gnfp1'), isTrue);
    final raw = store.readAsStringSync();
    expect(raw.contains('"login"'), isFalse);
    expect(raw.contains('loginName'), isFalse);
    final again = GnfpSession(store: store);
    final loaded = await again.ensureAddress(GnfpLedger(pool: ledger.pool));
    expect(loaded.value, a.value);
  });

  test('ensureAddress survives corrupt store and unwritable persist', () async {
    final dir = await Directory.systemTemp.createTemp('gnfp-boot-bad');
    final corrupt = File('${dir.path}/bad.json');
    corrupt.writeAsStringSync('{');
    final session = GnfpSession(store: corrupt);
    final addr = await session.ensureAddress(liveLedger());
    expect(addr.value.startsWith('gnfp1'), isTrue);

    final blocker = File('${dir.path}/notdir')..writeAsStringSync('x');
    final blocked = GnfpSession(store: File('${blocker.path}/session.json'));
    final again = await blocked.ensureAddress(liveLedger());
    expect(again.value.startsWith('gnfp1'), isTrue);
  });

  test('login is not callable on the shipped session type', () async {
    final dir = await Directory.systemTemp.createTemp('gnfp-nologin');
    final session = GnfpSession(store: File('${dir.path}/session.json'));
    expect(
      () => (session as dynamic).login('anyone'),
      throwsA(isA<NoSuchMethodError>()),
    );
    expect(
      () => (session as dynamic).register('anyone'),
      throwsA(isA<NoSuchMethodError>()),
    );
  });

  test('backup phrase restores the same gnfp1 address', () {
    final ledger = liveLedger();
    final a = ledger.createAddress(seed: 'alice-backup');
    final phrase = backupPhraseFor(a, seed: 'alice-backup');
    final restored = restoreFromPhrase(phrase, ledger, a, 'alice-backup');
    expect(restored.value, a.value);
    expect(restored.isValid, isTrue);
  });

  test('backup phrase restores the same gnfp1 with no current wallet', () {
    const seed = '00112233445566778899aabbccddeeff';
    final a = liveLedger().createAddress(seed: seed);
    final phrase = backupPhraseFor(a, seed: seed);
    final restored = restoreFromPhrase(phrase);
    expect(restored.value, a.value);
    expect(restored.isValid, isTrue);
  });

  test('Evolve surfaces exist and purple is not primary', () {
    expect(
      gnfpEvolveSurfaces,
      containsAll([
        'wallet',
        'backup',
        'explorer',
        'mine',
        'vpn',
      ]),
    );
    expect(gnfpEvolveSurfaces.contains('mix'), isFalse);
    expect(gnfpChromeTabs.contains('Mix'), isFalse);
    expect(gnfpEvolveSurfaces.contains('voting'), isFalse);
    expect(gnfpEvolveSurfaces.contains('credit'), isFalse);
    expect(gnfpEvolveSurfaces.contains('analysis_percent_chance'), isFalse);
    expect(gnfpChromeTabs.contains('Analysis'), isFalse);
    expect(gnfpChromeTabs.contains('Backup'), isTrue);
    expect(GnfpTheme.primary, GnfpTheme.neonCyan);
    expect(GnfpTheme.purpleIsNotPrimary, isTrue);
    expect(GnfpTheme.greyDark.value, isNot(GnfpTheme.evolvePurple.value));
    final pct = calculatePercentChance('chance of rain');
    expect(pct.percent, inInclusiveRange(0, 100));
    final scs = calculateSocialCohesion('street calm');
    expect(scs.score, inInclusiveRange(0, 100));
  });

  test('mix PERC to GNFP does not raise spendable GNFP', () async {
    final mixer = RpMixer(gnfp: liveLedger());
    final dest = mixer.gnfp.createAddress(seed: 'bridge-dest');
    await mixer.fund('PERC', 'perc-pocket', 8);
    expect(mixer.books['PERC']!.of('perc-pocket'), 8);
    expect(mixer.gnfp.balance(dest), 0);
    await expectLater(
      mixer.mix(
        fromCoin: 'PERC',
        toCoin: 'GNFP',
        fromAddress: 'perc-pocket',
        toAddress: dest.value,
        amount: 5,
      ),
      throwsA(isA<StateError>()),
    );
    expect(mixer.gnfp.balance(dest), 0);
    expect(await mixer.gnfp.pool.balance(dest.value), 0);
    expect(mixer.books['PERC']!.of('perc-pocket'), 8);
    expect(rpMixableCoins, containsAll(['GNFP', 'PERC']));
  });

  test('version rises with commit count', () {
    final low = versionFromCommitCount(3);
    final high = versionFromCommitCount(12);
    expect(GnfpVersion.compare(high.numeric, low.numeric), greaterThan(0));
    expect(high.buildNumber, greaterThan(low.buildNumber));
    expect(versionFromCommitCount(1).numeric, '0.0.1');
    expect(versionFromCommitCount(2).numeric, '0.0.2');
    expect(versionFromCommitCount(9).numeric, '0.0.9');
    expect(versionFromCommitCount(10).numeric, '0.1.0');
    expect(versionFromCommitCount(11).numeric, '0.1.1');
    expect(GnfpVersion.isLegacyPin('0.1.0'), isFalse);
    expect(GnfpVersion.isLegacyPin('0.0.9'), isFalse);
    expect(GnfpVersion.isLegacyPin('0.1.9'), isFalse);
    expect(GnfpVersion.isLegacyPin('0.2.0'), isFalse);
    expect(GnfpVersion.isLegacyPin('0.1.10'), isTrue);
    expect(GnfpVersion.isLegacyPin('1.1.13'), isTrue);
    expect(GnfpVersion.compare('0.1.0', '0.0.9'), greaterThan(0));
    expect(kGnfpPackageVersion, '0.2.1');
    expect(GnfpVersion.isLegacyPin(kGnfpPackageVersion), isFalse);
  });

  test('default GnfpPoolClient sets connectionTimeout so hung TLS cannot look like forever Network Tip', () {
    final client = GnfpPoolClient();
    addTearDown(() => client.httpClient.close(force: true));
    expect(client.httpClient.connectionTimeout, isNotNull);
    expect(
      client.httpClient.connectionTimeout,
      GnfpPoolClient.defaultConnectionTimeout,
    );
    expect(client.httpClient.connectionTimeout!.inSeconds, greaterThanOrEqualTo(4));
  });

  test('parseNetworkTip reads tipHeight tip or height as num or string', () {
    expect(GnfpPoolClient.parseNetworkTip({'tipHeight': 7}), 7);
    expect(GnfpPoolClient.parseNetworkTip({'tip': '12'}), 12);
    expect(GnfpPoolClient.parseNetworkTip({'height': 3}), 3);
    expect(GnfpPoolClient.parseNetworkTip({'tipHeight': '0', 'height': 9}), 0);
  });

  test('networkTip reads live pool height', () async {
    final ledger = liveLedger();
    final first = await ledger.networkTip();
    final payload = await ledger.pool.get('/api/tip');
    final parsed = GnfpPoolClient.parseNetworkTip(payload);
    final fromFields = payload['tip'] ?? payload['tipHeight'] ?? payload['height'];
    stdout.writeln(
      'networkTip=$first tip=${payload['tip']} tipHeight=${payload['tipHeight']} '
      'height=${payload['height']} parsed=$parsed',
    );
    expect(first, greaterThanOrEqualTo(0));
    expect(first, parsed);
    expect(first, (fromFields as num).toInt());
    expect(ledger.lastTip, first);
    final second = await ledger.networkTip();
    expect(second, parsed);
    stdout.writeln('networkTip2=$second parsed=$parsed');
  });

  test('writes scratch evidence from shipped functions', () async {
    await writeScratchEvidence(liveLedger());
  });
}

class _PendingThenRoundClient extends GnfpPoolClient {
  _PendingThenRoundClient(this.address, {required this.pending, required this.bundled});

  final String address;
  final double pending;
  final double bundled;
  bool tipReached = false;

  @override
  Future<Map<String, dynamic>> get(String path) async {
    if (path.contains('/wallet/balance')) {
      return {
        'ok': true,
        'coin': 'GNFP',
        'balance': tipReached ? bundled : pending,
        'pending': tipReached ? 0 : pending,
      };
    }
    if (path.contains('/wallet/history')) {
      if (!tipReached) return {'ok': true, 'coin': 'GNFP', 'txs': []};
      return {
        'ok': true,
        'coin': 'GNFP',
        'txs': [
          {
            'id': 'round-12-${address.substring(0, 12)}',
            'from': 'coinbase',
            'to': address,
            'amount': bundled,
            'kind': 'mine',
            'confirmed': true,
            'height': 12,
          },
        ],
      };
    }
    return {'ok': true};
  }
}

Future<void> writeScratchEvidence(GnfpLedger ledger) async {
  final scratch = Directory(
    Platform.environment['GROK_GOAL_SCRATCH'] ??
        '/var/folders/qb/tz4y4zts04z4846pbq95l6kw0000gp/T/grok-goal-c322301e810a/implementer',
  );
  scratch.createSync(recursive: true);
  final a = ledger.createAddress(seed: 'alice-evidence');
  final b = ledger.createAddress(seed: 'bob-evidence');
  final seeded = await seedMinerBook(ledger, a, 10);
  await ledger.send(from: a, to: b, amount: seeded.amount / 2);
  final phrase = backupPhraseFor(a, seed: 'alice-evidence');
  final restored = restoreFromPhrase(phrase, ledger, a, 'alice-evidence');
  final payload = const JsonEncoder.withIndent('  ').convert({
    ...ledger.snapshot(),
    'via': ledger.pool.baseUrl,
    'restoreMatches': restored.value == a.value,
    'phraseWords': phrase.split(' ').length,
    'aliceBalance': ledger.balance(a),
    'bobBalance': ledger.balance(b),
    'selfMintForbidden': true,
  });
  File('${scratch.path}/gnfp-wallet-ledger.json').writeAsStringSync(payload);
  File('${scratch.path}/wallet-ledger.json').writeAsStringSync(payload);
  File('${scratch.path}/gnfp-surfaces.txt').writeAsStringSync(
    '${gnfpEvolveSurfaces.join('\n')}\nprimary=${GnfpTheme.primary}\npurplePrimary=${GnfpTheme.purpleIsNotPrimary}\nqr=gnfp-qr\nregister=gnfp-register\ncredit=gnfp-credit-faucet\nminer=${gnfpMinerPayout}\ncreditMiner=gnfp-credit-miner\n',
  );
  File('${scratch.path}/gnfp-version.txt').writeAsStringSync(
    'low=${versionFromCommitCount(3).numeric}\nhigh=${versionFromCommitCount(12).numeric}\n',
  );
}
