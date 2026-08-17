import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gnfp_wallet/gnfp_analysis.dart';
import 'package:gnfp_wallet/gnfp_bridge.dart';
import 'package:gnfp_wallet/gnfp_ledger.dart';
import 'package:gnfp_wallet/gnfp_pool_client.dart';
import 'package:gnfp_wallet/gnfp_session.dart';
import 'package:gnfp_wallet/gnfp_surfaces.dart';
import 'package:gnfp_wallet/gnfp_theme.dart';
import 'package:gnfp_wallet/gnfp_version.dart';

import 'pool_harness.dart';

/// CPU work-hash the live book accepts (empty output, 16-hex nonce).
const cpuPreWork = 'gnfp-wallet-seed';
const cpuNonce = '0000000000000006';

Future<GnfpTx> seedMinerBook(
  GnfpLedger ledger,
  GnfpAddress to,
  double amount,
) {
  return ledger.miningReceive(
    to: to,
    amount: amount,
    nonce: cpuNonce,
    solution: '',
    preWork: cpuPreWork,
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

    await seedMinerBook(ledger, a, 10);
    expect(ledger.balance(a), 10);
    final sent = await ledger.send(from: a, to: b, amount: 3);
    expect(sent.kind, 'send');
    expect(ledger.balance(a), 7);
    expect(ledger.balance(b), 3);
    expect(gnfpTicker, 'GNFP');
    expect(gnfpStratum, contains('de.restoreprivacy.online:1474'));
    expect(await ledger.pool.balance(b.value), 3);
  });

  test('syncSpendable after an app update keeps the book balance on the same gnfp1', () async {
    final miner = liveLedger();
    final a = miner.createAddress(seed: 'upgrade-keep');
    await seedMinerBook(miner, a, 25);
    expect(await miner.pool.balance(a.value), 25);

    final upgraded = liveLedger();
    upgraded.adopt(a);
    expect(upgraded.balance(a), 0);
    final live = await upgraded.syncSpendable(a);
    expect(live, 25);
    expect(upgraded.balance(a), 25);
    expect(a.value, miner.createAddress(seed: 'upgrade-keep').value);
  });

  test('credit from your miner pulls live miner book without posting extra', () async {
    final miner = liveLedger();
    final a = miner.createAddress(seed: 'miner-pull');
    await seedMinerBook(miner, a, 50);
    expect(miner.balance(a), 50);

    final wallet = liveLedger();
    wallet.adopt(a);
    expect(wallet.balance(a), 0);
    final tx = await wallet.creditFromMiner(to: a);
    expect(tx.kind, 'miner');
    expect(tx.memo, 'credit from your miner');
    expect(tx.from, gnfpStratum);
    expect(wallet.balance(a), 50);
    expect(await wallet.pool.balance(a.value), 50);

    final again = await wallet.creditFromMiner(to: a);
    expect(again.amount, 0);
    expect(wallet.balance(a), 50);
    expect(await wallet.pool.balance(a.value), 50);
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
    final phrase = backupPhraseFor(a);
    final restored = restoreFromPhrase(phrase, ledger);
    expect(restored.value, a.value);
    expect(restored.isValid, isTrue);
  });

  test('Evolve surfaces exist and purple is not primary', () {
    expect(
      gnfpEvolveSurfaces,
      containsAll([
        'analysis_percent_chance',
        'analysis_scs',
        'wallet',
        'backup',
        'explorer',
        'mix',
        'mine',
        'vpn',
      ]),
    );
    expect(gnfpEvolveSurfaces.contains('voting'), isFalse);
    expect(gnfpEvolveSurfaces.contains('credit'), isFalse);
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

Future<void> writeScratchEvidence(GnfpLedger ledger) async {
  final scratch = Directory(
    Platform.environment['GROK_GOAL_SCRATCH'] ??
        '/var/folders/qb/tz4y4zts04z4846pbq95l6kw0000gp/T/grok-goal-f566d95a8b14/implementer',
  );
  scratch.createSync(recursive: true);
  final a = ledger.createAddress(seed: 'alice-evidence');
  final b = ledger.createAddress(seed: 'bob-evidence');
  await seedMinerBook(ledger, a, 10);
  await ledger.send(from: a, to: b, amount: 3);
  final phrase = backupPhraseFor(a);
  final restored = restoreFromPhrase(phrase, ledger);
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
