import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnfp_wallet/copyable_address.dart';
import 'package:gnfp_wallet/gnfp_ledger.dart';
import 'package:gnfp_wallet/gnfp_pool_client.dart';
import 'package:gnfp_wallet/gnfp_session.dart';
import 'package:gnfp_wallet/gnfp_build_stamp.dart';
import 'package:gnfp_wallet/gnfp_version.dart';
import 'package:gnfp_wallet/gnfp_theme.dart';
import 'package:gnfp_wallet/gnfp_update.dart';
import 'package:gnfp_wallet/main.dart';

import 'pool_harness.dart';

/// Wallet tab owns a 3s poll timer; pumpAndSettle never idles while it is mounted.
Future<void> pumpBoot(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('GNFP wallet shell shows version, QR, send, credit — no register', (tester) async {
    final store = File('${Directory.systemTemp.path}/gnfp-widget-session.json');
    if (store.existsSync()) store.deleteSync();
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      GnfpWalletApp(
        ledger: GnfpLedger(),
        version: '1.1.13',
        session: GnfpSession(store: store),
        updateCheck: GnfpUpdateCheck(fetchJson: (_) async => null),
      ),
    );
    await pumpBoot(tester);
    expect(find.byKey(const Key('gnfp-shell')), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.colorScheme.primary, GnfpTheme.neonCyan);
    expect(app.theme!.scaffoldBackgroundColor, GnfpTheme.navy);
    expect(find.textContaining('GNFP'), findsWidgets);
    expect(find.textContaining('1.1.13'), findsWidgets);
    expect(find.byKey(const Key('gnfp-update-banner')), findsNothing);
    expect(find.text('Analysis'), findsWidgets);
    expect(find.text('Wallet'), findsWidgets);
    expect(find.text('Backup'), findsWidgets);
    expect(find.text('Voting'), findsWidgets);
    expect(find.text('Credit'), findsWidgets);
    expect(find.text('Explorer'), findsWidgets);
    expect(find.text('Mix'), findsWidgets);

    await tester.tap(find.byIcon(Icons.account_balance_wallet));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('gnfp-register')), findsNothing);
    expect(find.byKey(const Key('gnfp-register-name')), findsNothing);
    expect(find.text('Register / login'), findsNothing);
    expect(find.byKey(const Key('gnfp-qr')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-send')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-address')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-mine-receive')), findsNothing);
    expect(find.byKey(const Key('gnfp-receive')), findsNothing);
    expect(find.text('Receive'), findsNothing);
    expect(find.text('Mining receive'), findsNothing);
    expect(find.byKey(const Key('gnfp-receive-hint')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.payments));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('gnfp-credit-faucet')), findsNothing);
    expect(find.text('Credit from scenario'), findsNothing);
    expect(find.byKey(const Key('gnfp-credit-miner')), findsOneWidget);
    expect(find.text('Credit from your miner'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.backup));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('gnfp-backup-phrase')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-restore')), findsOneWidget);
  });

  testWidgets('Mix go does not raise GNFP on the shipped shell', (tester) async {
    final store = File('${Directory.systemTemp.path}/gnfp-widget-session-mix.json');
    if (store.existsSync()) store.deleteSync();
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final ledger = GnfpLedger();
    await tester.pumpWidget(
      GnfpWalletApp(
        ledger: ledger,
        version: '1.1.13',
        session: GnfpSession(store: store),
        updateCheck: GnfpUpdateCheck(fetchJson: (_) async => null),
      ),
    );
    await pumpBoot(tester);
    final addr = tester.widget<CopyableAddress>(find.byKey(const Key('gnfp-address'))).address;
    expect(ledger.balance(GnfpAddress(addr)), 0);

    await tester.tap(find.byIcon(Icons.swap_horiz));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('gnfp-mix-go')), findsOneWidget);
    expect(find.textContaining('GNFP balance 0'), findsOneWidget);

    await tester.tap(find.byKey(const Key('gnfp-mix-go')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('GNFP balance 0'), findsOneWidget);
    expect(find.textContaining('self_mint_forbidden'), findsOneWidget);
    expect(ledger.balance(GnfpAddress(addr)), 0);
    expect(find.byKey(const Key('gnfp-receive')), findsNothing);
    expect(find.byKey(const Key('gnfp-credit-faucet')), findsNothing);
  });

  testWidgets('boot still shows no-login shell when update fetch throws', (tester) async {
    final store = File('${Directory.systemTemp.path}/gnfp-widget-session-throw.json');
    if (store.existsSync()) store.deleteSync();
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      GnfpWalletApp(
        ledger: GnfpLedger(),
        session: GnfpSession(store: store),
        updateCheck: GnfpUpdateCheck(
          fetchJson: (_) async => throw StateError('update feed exploded'),
        ),
      ),
    );
    await pumpBoot(tester);
    expect(find.byKey(const Key('gnfp-shell')), findsOneWidget);
    expect(find.text('GNFP 1.1.13'), findsOneWidget);
    expect(find.text('Register / login'), findsNothing);
    expect(find.byKey(const Key('gnfp-register')), findsNothing);
    expect(find.byKey(const Key('gnfp-qr')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-update-banner')), findsNothing);
  });

  testWidgets('boot still shows no-login shell with corrupt session store', (tester) async {
    final store = File('${Directory.systemTemp.path}/gnfp-widget-session-bad.json');
    store.writeAsStringSync('not-json{{{');
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      GnfpWalletApp(
        ledger: GnfpLedger(),
        commitCount: 11,
        session: GnfpSession(store: store),
        updateCheck: GnfpUpdateCheck(fetchJson: (_) async => null),
      ),
    );
    await pumpBoot(tester);
    expect(find.byKey(const Key('gnfp-shell')), findsOneWidget);
    expect(find.text('Register / login'), findsNothing);
    expect(find.byKey(const Key('gnfp-qr')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-address')), findsOneWidget);
  });

  testWidgets('boot still shows no-login shell when session persist cannot write', (tester) async {
    final blocker = File('${Directory.systemTemp.path}/gnfp-persist-notdir');
    blocker.writeAsStringSync('x');
    final store = File('${Directory.systemTemp.path}/gnfp-persist-notdir/session.json');
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      GnfpWalletApp(
        ledger: GnfpLedger(),
        commitCount: 11,
        session: GnfpSession(store: store),
        updateCheck: GnfpUpdateCheck(fetchJson: (_) async => null),
      ),
    );
    await pumpBoot(tester);
    expect(find.byKey(const Key('gnfp-shell')), findsOneWidget);
    expect(find.text('Register / login'), findsNothing);
    expect(find.byKey(const Key('gnfp-qr')), findsOneWidget);
  });

  testWidgets('old client shows update banner with direct installer URL', (tester) async {
    final store = File('${Directory.systemTemp.path}/gnfp-widget-session-upd.json');
    if (store.existsSync()) store.deleteSync();
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      GnfpWalletApp(
        ledger: GnfpLedger(),
        version: '0.1.10',
        session: GnfpSession(store: store),
        updatePlatform: 'windows',
        updateCheck: GnfpUpdateCheck(
          fetchJson: (_) async => {
            'tag_name': 'v0.1.11',
            'html_url': 'https://github.com/rgsneddon/gnfp/releases/tag/v0.1.11',
            'assets': [
              {
                'name': 'gnfp-wallet-0.1.11-windows.zip',
                'browser_download_url':
                    'https://github.com/rgsneddon/gnfp/releases/download/v0.1.11/gnfp-wallet-0.1.11-windows.zip',
              },
            ],
          },
        ),
      ),
    );
    await pumpBoot(tester);
    expect(find.byKey(const Key('gnfp-update-banner')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-update-url')), findsOneWidget);
    expect(
      find.textContaining('gnfp-wallet-0.1.11-windows.zip'),
      findsOneWidget,
    );
    expect(find.text('Register / login'), findsNothing);
  });

  testWidgets('default launch chrome remarks stamped package version not 0.0.1', (tester) async {
    final store = File('${Directory.systemTemp.path}/gnfp-widget-session-stamp.json');
    if (store.existsSync()) store.deleteSync();
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    expect(kGnfpPackageVersion, isNot('0.0.1'));
    expect(kGnfpPackageVersion, '1.1.13');
    expect(kGnfpCommitCount, greaterThan(1));
    await tester.pumpWidget(
      GnfpWalletApp(
        ledger: GnfpLedger(),
        session: GnfpSession(store: store),
        updateCheck: GnfpUpdateCheck(fetchJson: (_) async => null),
      ),
    );
    await pumpBoot(tester);
    expect(find.text('GNFP $kGnfpPackageVersion'), findsOneWidget);
    expect(find.textContaining('0.0.1'), findsNothing);
    expect(
      GnfpVersion.compare(kGnfpPackageVersion, versionFromCommitCount(1).numeric),
      greaterThan(0),
    );
  });

  testWidgets('Wallet tab Network tip shows live numeric height after sync', (tester) async {
    HttpOverrides.global = RealHttpOverrides();
    addTearDown(() {
      HttpOverrides.global = null;
    });
    final pool = await tester.runAsync(startShippedPool);
    expect(pool, isNotNull);
    addTearDown(() async {
      await tester.runAsync(pool!.stop);
    });

    final store = File('${Directory.systemTemp.path}/gnfp-widget-session-tip.json');
    if (store.existsSync()) store.deleteSync();
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final ledger = GnfpLedger(pool: GnfpPoolClient(baseUrl: pool!.uri.toString()));
    final expected = await tester.runAsync(ledger.networkTip);
    expect(expected, isNotNull);
    expect(expected, greaterThanOrEqualTo(0));
    expect(ledger.lastTip, expected);

    await tester.pumpWidget(
      GnfpWalletApp(
        ledger: ledger,
        commitCount: 4,
        session: GnfpSession(store: store),
        updateCheck: GnfpUpdateCheck(fetchJson: (_) async => null),
      ),
    );
    await pumpBoot(tester);

    await tester.tap(find.byIcon(Icons.account_balance_wallet));
    await tester.pump();

    expect(find.byKey(const Key('gnfp-network-tip')), findsOneWidget);
    expect(find.text('Network tip $expected'), findsOneWidget);
    expect(find.text('Network tip …'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
