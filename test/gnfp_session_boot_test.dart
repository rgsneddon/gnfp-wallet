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
    expect(find.text('Analysis'), findsWidgets);
    expect(find.text('Wallet'), findsWidgets);
    expect(find.text('Backup'), findsWidgets);
  });
}
