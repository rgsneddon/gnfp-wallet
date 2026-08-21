import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnfp_wallet/gnfp_ledger.dart';
import 'package:gnfp_wallet/gnfp_seed.dart';
import 'package:gnfp_wallet/gnfp_session.dart';
import 'package:gnfp_wallet/screens/backup_screen.dart';

void main() {
  test('current 12-word phrase restores the same gnfp1', () {
    final ledger = GnfpLedger();
    const seed = 'keep-me';
    final addr = ledger.createAddress(seed: seed);
    final phrase = backupPhraseFor(addr, seed: seed);
    expect(gnfpPhraseWords(phrase), hasLength(12));
    expect(restoreFromPhrase(phrase, ledger, addr, seed).value, addr.value);
  });

  test('restoreFromPhrase with no current wallet returns the original gnfp1', () {
    final created = GnfpLedger();
    const seed = '00112233445566778899aabbccddeeff';
    final addr = created.createAddress(seed: seed);
    final phrase = backupPhraseFor(addr, seed: seed);
    expect(gnfpPhraseWords(phrase), hasLength(12));
    final restored = restoreFromPhrase(phrase);
    expect(restored.value, addr.value);
    expect(restoreSeedHexFromPhrase(phrase), seed);
  });

  test('production-style random seed phrase round-trips on a fresh ledger', () {
    final sessionLedger = GnfpLedger();
    final seed = List.generate(16, (i) => i).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final addr = sessionLedger.createAddress(seed: seed);
    final phrase = backupPhraseFor(addr, seed: seed);
    final restored = restoreFromPhrase(phrase, GnfpLedger());
    expect(restored.value, addr.value);
  });

  test('wrong 12 words mint a different empty gnfp1', () {
    final ledger = GnfpLedger();
    const seed = 'keep-me';
    final addr = ledger.createAddress(seed: seed);
    ledger.rememberSpendable(addr, 9);
    const wrong = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    final next = restoreFromPhrase(wrong, ledger, addr, seed);
    expect(next.value, isNot(addr.value));
    expect(ledger.balance(next), 0);
  });

  testWidgets('backup shows 12 boxes, copy/paste, yellow warning', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final ledger = GnfpLedger();
    const seed = 'box-seed';
    final addr = ledger.createAddress(seed: seed);
    var clip = backupPhraseFor(addr, seed: seed);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BackupScreen(
            address: addr,
            ledger: ledger,
            seed: seed,
            clipboard: ClipboardDelegate(
              read: () async => clip,
              write: (t) async {
                clip = t;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('gnfp-seed-box-0')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-seed-box-11')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-copy-phrase')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-paste-phrase')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-wrong-phrase-warning')), findsOneWidget);
    expect(find.textContaining('wrong 12-word phrase'), findsOneWidget);
    expect(find.text(gnfpWrongPhraseWarning), findsOneWidget);
    final warningCopy = tester.widget<Text>(find.text(gnfpWrongPhraseWarning));
    final warningBlock = tester.widget<Container>(
      find.byKey(const Key('gnfp-wrong-phrase-warning')),
    );
    final deco = warningBlock.decoration! as BoxDecoration;
    const neonYellow = Color(0xFFFFE600);
    expect(warningCopy.style?.color, isNot(neonYellow));
    expect(warningCopy.style?.color, isNot(deco.color));
    expect(warningCopy.style?.color, isNot(deco.boxShadow!.first.color));
    expect(deco.color, isNot(warningCopy.style?.color));
    await tester.tap(find.byKey(const Key('gnfp-copy-phrase')));
    await tester.pump();
    expect(clip.split(' '), hasLength(12));
    await tester.enterText(find.byKey(const Key('gnfp-seed-box-0')), 'zzzz');
    await tester.pump();
    await tester.tap(find.byKey(const Key('gnfp-paste-phrase')));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(const Key('gnfp-seed-box-0'))).controller?.text,
      gnfpPhraseWords(clip).first,
    );
    await tester.tap(find.byKey(const Key('gnfp-restore')));
    await tester.pump();
    expect(find.textContaining('restored ${addr.value}'), findsOneWidget);
  });

  testWidgets('restore of another 12-word phrase reports that seed', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final ledger = GnfpLedger();
    const seed = '00112233445566778899aabbccddeeff';
    final addr = ledger.createAddress(seed: seed);
    GnfpAddress? gotAddr;
    String? gotSeed;
    const wrong =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BackupScreen(
            address: addr,
            ledger: ledger,
            seed: seed,
            onRestored: (a, s) {
              gotAddr = a;
              gotSeed = s;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    final words = gnfpPhraseWords(wrong);
    for (var i = 0; i < 12; i++) {
      await tester.enterText(find.byKey(Key('gnfp-seed-box-$i')), words[i]);
    }
    await tester.tap(find.byKey(const Key('gnfp-restore')));
    await tester.pump();
    expect(gotAddr!.value, isNot(addr.value));
    expect(gotSeed, restoreSeedHexFromPhrase(wrong));
    expect(restoreFromPhrase(wrong).value, gotAddr!.value);
    expect(ledger.balance(gotAddr!), 0);
  });

  /// Same persist path as `GnfpWalletApp`: Restore → restoreFromPhrase →
  /// `session.rememberAddress` (awaited). Reload of the same store is truth.
  Future<void> pumpPersistingBackup(
    WidgetTester tester, {
    required GnfpSession session,
    required GnfpLedger ledger,
    required GnfpAddress address,
    required String seed,
    String clipboard = '',
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    var clip = clipboard;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BackupScreen(
            address: address,
            ledger: ledger,
            seed: seed,
            clipboard: ClipboardDelegate(
              read: () async => clip,
              write: (t) async {
                clip = t;
              },
            ),
            onRestored: (a, nextSeed) async {
              await session.rememberAddress(ledger, a, seed: nextSeed);
            },
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Backup Restore of another 12-word phrase persists and reloads that gnfp1', (tester) async {
    final store = File(
      '${Directory.systemTemp.path}/gnfp-restore-other-${DateTime.now().microsecondsSinceEpoch}/session.json',
    );
    store.parent.createSync(recursive: true);
    const seed = '00112233445566778899aabbccddeeff';
    final ledger = GnfpLedger();
    final first = ledger.createAddress(seed: seed);
    store.writeAsStringSync(
      '{"seed":"$seed","address":"${first.value}","schema":2}',
    );
    final session = GnfpSession(store: store);
    const other =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    await pumpPersistingBackup(
      tester,
      session: session,
      ledger: ledger,
      address: first,
      seed: seed,
      clipboard: other,
    );
    await tester.runAsync(() async {
      tester.widget<FilledButton>(find.byKey(const Key('gnfp-paste-phrase'))).onPressed!();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(const Key('gnfp-seed-box-0'))).controller?.text,
      gnfpPhraseWords(other).first,
    );
    await tester.runAsync(() async {
      tester.widget<FilledButton>(find.byKey(const Key('gnfp-restore'))).onPressed!();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    final expected = restoreFromPhrase(other);
    expect(expected.value, isNot(first.value));
    expect(find.textContaining('restored ${expected.value}'), findsOneWidget);
    final again = GnfpSession(store: store);
    expect((await again.load(GnfpLedger()))!.value, expected.value);
    expect(again.seed, restoreSeedHexFromPhrase(other));
    expect(again.seed, isNot(seed));
  });

  testWidgets('Backup Restore of the displayed phrase keeps the current wallet', (tester) async {
    final store = File(
      '${Directory.systemTemp.path}/gnfp-restore-keep-${DateTime.now().microsecondsSinceEpoch}/session.json',
    );
    store.parent.createSync(recursive: true);
    const seed = 'ffeeddccbbaa99887766554433221100';
    final ledger = GnfpLedger();
    final first = ledger.createAddress(seed: seed);
    store.writeAsStringSync(
      '{"seed":"$seed","address":"${first.value}","schema":2}',
    );
    final session = GnfpSession(store: store);
    await pumpPersistingBackup(
      tester,
      session: session,
      ledger: ledger,
      address: first,
      seed: seed,
    );
    await tester.runAsync(() async {
      tester.widget<FilledButton>(find.byKey(const Key('gnfp-restore'))).onPressed!();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(find.textContaining('restored ${first.value}'), findsOneWidget);
    final again = GnfpSession(store: store);
    expect((await again.load(GnfpLedger()))!.value, first.value);
    expect(again.seed, seed);
  });

  testWidgets('Backup Restore of the 0.1.6 hashed phrase keeps the current wallet', (tester) async {
    final store = File(
      '${Directory.systemTemp.path}/gnfp-restore-hashed-${DateTime.now().microsecondsSinceEpoch}/session.json',
    );
    store.parent.createSync(recursive: true);
    const seed = 'aabbccddeeff00112233445566778899';
    final ledger = GnfpLedger();
    final first = ledger.createAddress(seed: seed);
    store.writeAsStringSync(
      '{"seed":"$seed","address":"${first.value}","schema":2}',
    );
    final hashed = legacyHashedBackupPhrase(first, seed: seed);
    expect(hashed, isNot(backupPhraseFor(first, seed: seed)));
    final session = GnfpSession(store: store);
    await pumpPersistingBackup(
      tester,
      session: session,
      ledger: ledger,
      address: first,
      seed: seed,
      clipboard: hashed,
    );
    await tester.runAsync(() async {
      tester.widget<FilledButton>(find.byKey(const Key('gnfp-paste-phrase'))).onPressed!();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(const Key('gnfp-seed-box-0'))).controller?.text,
      gnfpPhraseWords(hashed).first,
    );
    await tester.runAsync(() async {
      tester.widget<FilledButton>(find.byKey(const Key('gnfp-restore'))).onPressed!();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(find.textContaining('restored ${first.value}'), findsOneWidget);
    final again = GnfpSession(store: store);
    expect((await again.load(GnfpLedger()))!.value, first.value);
    expect(again.seed, seed);
  });
}
