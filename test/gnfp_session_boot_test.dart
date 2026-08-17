import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnfp_wallet/gnfp_ledger.dart';
import 'package:gnfp_wallet/gnfp_session.dart';
import 'package:gnfp_wallet/gnfp_update.dart';
import 'package:gnfp_wallet/main.dart';

/// A path whose parent is a file, so exists/create throws (sandbox analogue).
File deniedSessionStore() {
  final blocker = File(
    '${Directory.systemTemp.path}/gnfp-denied-parent-${DateTime.now().microsecondsSinceEpoch}',
  );
  blocker.writeAsStringSync('not-a-directory');
  addTearDown(() {
    if (blocker.existsSync()) blocker.deleteSync();
  });
  return File('${blocker.path}/session.json');
}

void main() {
  test('default Mac store is Application Support, not ~/.gnfp', () {
    final path = GnfpSession.macDefaultStorePath('/Users/rus');
    expect(path, '/Users/rus/Library/Application Support/GNFP/session.json');
    expect(path, isNot(contains('/.gnfp/')));
    if (Platform.isMacOS) {
      expect(
        GnfpSession.defaultStore().path,
        contains('Library/Application Support/GNFP/session.json'),
      );
    }
  });

  test('bootLoad on unwritable/missing parent returns null and does not throw', () async {
    final session = GnfpSession(store: deniedSessionStore());
    final loaded = await bootLoad(session, GnfpLedger());
    expect(loaded, isNull);
  });

  test('persist on unwritable parent does not throw', () async {
    final session = GnfpSession(store: deniedSessionStore());
    session.seed = 'rus';
    session.address = GnfpLedger().createAddress(seed: 'rus');
    await session.persist();
    final loaded = await session.load(GnfpLedger());
    expect(loaded, isNull);
  });

  test('ensureAddress still returns an address when persist cannot write', () async {
    final session = GnfpSession(store: deniedSessionStore());
    final addr = await session.ensureAddress(GnfpLedger());
    expect(addr.value.startsWith('gnfp1'), isTrue);
  });

  test('old login-shaped store keeps the same gnfp1 after a version bump', () async {
    final dir = await Directory.systemTemp.createTemp('gnfp-old-store');
    final store = File('${dir.path}/session.json');
    const kept = 'gnfp1aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    store.writeAsStringSync(
      '{"login":"rus","loginName":"rus","addr":"$kept","schema":1}',
    );
    final rec = GnfpSession.parseStore(
      {'login': 'rus', 'addr': kept, 'schema': 1},
    );
    expect(rec, isNotNull);
    expect(rec!.address, kept);
    final first = GnfpSession(store: store);
    final ledger = GnfpLedger();
    final loaded = await first.ensureAddress(ledger);
    expect(loaded.value, kept);
    final again = GnfpSession(store: store);
    final same = await again.ensureAddress(GnfpLedger());
    expect(same.value, kept);
    final raw = store.readAsStringSync();
    expect(raw.contains('"login"'), isFalse);
    expect(raw.contains(kept), isTrue);
  });

  test('legacy ~/.gnfp session migrates into the new store without minting', () async {
    final dir = await Directory.systemTemp.createTemp('gnfp-legacy-mig');
    final old = File('${dir.path}/.gnfp/session.json')..parent.createSync(recursive: true);
    final next = File('${dir.path}/Library/Application Support/GNFP/session.json');
    const kept = 'gnfp1bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    old.writeAsStringSync('{"address":"$kept","seed":"legacy-seed"}');
    final session = GnfpSession(store: next, legacyStores: [old]);
    final addr = await session.ensureAddress(GnfpLedger());
    expect(addr.value, kept);
    expect(next.existsSync(), isTrue);
    expect(next.readAsStringSync().contains(kept), isTrue);
    final second = GnfpSession(store: next, legacyStores: [old]);
    expect((await second.ensureAddress(GnfpLedger())).value, kept);
  });

  test('0.0.7 sandbox container session migrates after the un-sandboxed 0.0.8 install', () {
    final paths = GnfpSession.defaultLegacyStores(home: '/Users/amy').map((f) => f.path);
    expect(
      paths,
      contains(
        '/Users/amy/Library/Containers/online.restoreprivacy.gnfpWallet/Data/Library/Application Support/GNFP/session.json',
      ),
    );
  });

  test('parseStore restores a backup phrase and ignores empty login-only files', () {
    final a = GnfpLedger().createAddress(seed: 'phrase-keep');
    final phrase = backupPhraseFor(a);
    final rec = GnfpSession.parseStore({'backupPhrase': phrase, 'loginName': 'x'});
    expect(rec!.address, a.value);
    expect(GnfpSession.parseStore({'login': 'only'}), isNull);
  });

  testWidgets('denied session store still reaches ready GNFP destinations', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      GnfpWalletApp(
        ledger: GnfpLedger(),
        commitCount: 4,
        session: GnfpSession(store: deniedSessionStore()),
        updateCheck: GnfpUpdateCheck(fetchJson: (_) async => null),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Wallet'), findsWidgets);
    expect(find.text('Explorer'), findsWidgets);
    expect(find.text('Backup'), findsWidgets);
    expect(find.text('VPN'), findsWidgets);
    expect(find.text('Voting'), findsNothing);
  });
}
