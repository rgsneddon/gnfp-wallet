import 'dart:convert';
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
import 'package:gnfp_wallet/screens/explorer_screen.dart';
import 'package:gnfp_wallet/screens/wallet_screen.dart';

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
        version: '0.0.5',
        session: GnfpSession(store: store),
        updateCheck: GnfpUpdateCheck(fetchJson: (_) async => null),
      ),
    );
    await pumpBoot(tester);
    expect(find.byKey(const Key('gnfp-shell')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-logo')), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, r'$GNFP core wallet v0.0.5');
    await tester.tap(find.byIcon(Icons.explore));
    await tester.pump();
    final explorer = tester.widget<ExplorerScreen>(find.byType(ExplorerScreen));
    expect(explorer.pickExportFile, isNotNull);
    await tester.tap(find.byIcon(Icons.account_balance_wallet));
    await tester.pump();
    expect(app.theme!.colorScheme.primary, GnfpTheme.neonCyan);
    expect(app.theme!.scaffoldBackgroundColor, GnfpTheme.black);
    expect(find.textContaining('GNFP'), findsWidgets);
    expect(find.text('GNFPv0.0.5'), findsOneWidget);
    expect(find.byKey(const Key('gnfp-update-banner')), findsNothing);
    expect(find.byKey(const Key('gnfp-update-url')), findsNothing);
    expect(find.text('Wallet'), findsWidgets);
    expect(find.text('Explorer'), findsWidgets);
    expect(find.text('Backup'), findsWidgets);
    expect(find.text('Mix'), findsNothing);
    expect(find.text('Analysis'), findsNothing);
    expect(find.text('Mine'), findsWidgets);
    expect(find.text('VPN'), findsWidgets);
    expect(find.text('Voting'), findsNothing);
    expect(find.text('Credit'), findsNothing);
    expect(find.byKey(const Key('gnfp-box-identity')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-box-holdings')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-box-send')), findsOneWidget);
    expect(find.text('Wallet'), findsWidgets);
    expect(find.text('GNFP Wallet'), findsOneWidget);
    final idBox = tester.getSize(find.byKey(const Key('gnfp-box-identity')));
    final logoSize = tester.getSize(find.byKey(const Key('gnfp-logo')));
    expect(logoSize.height, moreOrLessEquals(idBox.height, epsilon: 2.5));
    void expectPaintsFull(Finder finder, String value) {
      final text = tester.widget<Text>(finder);
      final painter = TextPainter(
        text: TextSpan(text: value, style: text.style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      expect(tester.getSize(finder).width, greaterThanOrEqualTo(painter.width - 0.5));
    }

    expectPaintsFull(find.text('GNFP Wallet'), 'GNFP Wallet');
    expectPaintsFull(find.byKey(const Key('gnfp-version')), 'GNFPv0.0.5');

    await tester.tap(find.byIcon(Icons.account_balance_wallet));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('gnfp-register')), findsNothing);
    expect(find.byKey(const Key('gnfp-register-name')), findsNothing);
    expect(find.text('Register / login'), findsNothing);
    expect(find.byKey(const Key('gnfp-qr')), findsNothing);
    expect(find.byKey(const Key('gnfp-qr-popup')), findsNothing);
    expect(find.byKey(const Key('gnfp-show-qr')), findsOneWidget);
    await tester.tap(find.byKey(const Key('gnfp-show-qr')));
    await tester.pump();
    expect(find.byKey(const Key('gnfp-qr-popup')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-qr')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-qr-address')), findsOneWidget);
    await tester.tap(find.byKey(const Key('gnfp-qr-close')));
    await tester.pump();
    expect(find.byKey(const Key('gnfp-qr-popup')), findsNothing);
    expect(find.byKey(const Key('gnfp-send')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-address')), findsOneWidget);
    expect(find.textContaining('Address:'), findsNothing);
    expect(find.byKey(const Key('gnfp-mine-receive')), findsNothing);
    expect(find.byKey(const Key('gnfp-receive')), findsNothing);
    expect(find.text('Receive'), findsNothing);
    expect(find.text('Mining receive'), findsNothing);
    expect(find.byKey(const Key('gnfp-receive-hint')), findsNothing);
    expect(find.byKey(const Key('gnfp-miner-cmd')), findsNothing);
    expect(find.textContaining('perc-mine'), findsNothing);
    expect(find.byKey(const Key('gnfp-credit-miner')), findsNothing);
    expect(find.text('Credit wallet with pending GNFP'), findsNothing);
    expect(find.text('SOCIAL CHANNELS'), findsOneWidget);
    expect(find.text('DISCORD'), findsOneWidget);
    expect(find.text('TELEGRAM'), findsOneWidget);
    expect(find.text('BitcoinTalk'), findsOneWidget);
    expect(find.textContaining('discord.com'), findsNothing);
    expect(find.textContaining('t.me/'), findsNothing);
    expect(find.textContaining('bitcointalk.org'), findsNothing);
    final sendDx = tester.getTopLeft(find.byKey(const Key('gnfp-send'))).dx;
    final toDx = tester.getTopLeft(find.byKey(const Key('gnfp-send-to'))).dx;
    expect(sendDx, lessThan(toDx));

    await tester.tap(find.byIcon(Icons.shield));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('gnfp-vpn-coming-soon')), findsOneWidget);
    expect(find.text('coming soon'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.backup));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('gnfp-backup-phrase')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-restore')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.explore));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('gnfp-owner-ledger')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.memory));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('gnfp-miner-cmd')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-mine-start')), findsOneWidget);
    expect(find.text('MINE GNFP'), findsOneWidget);
    final cmd = tester.widget<SelectableText>(find.byKey(const Key('gnfp-miner-cmd'))).data ?? '';
    expect(cmd, contains('de.restoreprivacy.online:1474'));
    expect(cmd.contains('--notls'), isFalse);
    expect(cmd, contains('--user'));
    expect(cmd, contains('.worker'));
  });

  testWidgets('phone-width wallet paints full balance above the send box', (tester) async {
    final store = File('${Directory.systemTemp.path}/gnfp-widget-session-phone.json');
    if (store.existsSync()) store.deleteSync();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      GnfpWalletApp(
        ledger: GnfpLedger(),
        version: '0.1.2',
        session: GnfpSession(store: store),
        updateCheck: GnfpUpdateCheck(fetchJson: (_) async => null),
      ),
    );
    await pumpBoot(tester);

    const balanceText = 'Balance: 0.00000000 GNFP';
    expect(find.byKey(const Key('gnfp-balance')), findsOneWidget);
    expect(find.text(balanceText), findsOneWidget);
    expect(find.byKey(const Key('gnfp-network-tip')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-address')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-box-send')), findsOneWidget);

    void expectPaintsFull(Finder finder, String value) {
      final text = tester.widget<Text>(finder);
      final painter = TextPainter(
        text: TextSpan(text: value, style: text.style),
        maxLines: 2,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: tester.getSize(finder).width);
      expect(tester.getSize(finder).height, greaterThanOrEqualTo(painter.height - 0.5));
      expect(painter.didExceedMaxLines, isFalse);
    }

    expectPaintsFull(find.byKey(const Key('gnfp-balance')), balanceText);
    expectPaintsFull(find.byKey(const Key('gnfp-network-tip')), 'Network Tip: …');

    final id = tester.getRect(find.byKey(const Key('gnfp-box-identity')));
    final hold = tester.getRect(find.byKey(const Key('gnfp-box-holdings')));
    final send = tester.getRect(find.byKey(const Key('gnfp-box-send')));
    expect(hold.top, greaterThanOrEqualTo(id.bottom - 0.5));
    expect(send.top, greaterThanOrEqualTo(hold.bottom - 0.5));
    expect(hold.width, greaterThan(300));
  });

  testWidgets('Mix surface is gone from the shipped shell', (tester) async {
    final store = File('${Directory.systemTemp.path}/gnfp-widget-session-mix.json');
    if (store.existsSync()) store.deleteSync();
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      GnfpWalletApp(
        ledger: GnfpLedger(),
        version: '0.0.5',
        session: GnfpSession(store: store),
        updateCheck: GnfpUpdateCheck(fetchJson: (_) async => null),
      ),
    );
    await pumpBoot(tester);
    expect(find.text('Mix'), findsNothing);
    expect(find.byIcon(Icons.swap_horiz), findsNothing);
    expect(find.byKey(const Key('gnfp-mix-go')), findsNothing);
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
    expect(find.textContaining('GNFPv'), findsOneWidget);
    expect(find.text('Register / login'), findsNothing);
    expect(find.byKey(const Key('gnfp-register')), findsNothing);
    expect(find.byKey(const Key('gnfp-show-qr')), findsOneWidget);
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
    expect(find.byKey(const Key('gnfp-show-qr')), findsOneWidget);
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
    expect(find.byKey(const Key('gnfp-show-qr')), findsOneWidget);
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
    expect(
      tester.getTopLeft(find.byKey(const Key('gnfp-update-banner'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('gnfp-box-identity'))).dy),
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
    expect(kGnfpPackageVersion, isNot('0.0.2'));
    expect(kGnfpCommitCount, greaterThan(1));
    await tester.pumpWidget(
      GnfpWalletApp(
        ledger: GnfpLedger(),
        session: GnfpSession(store: store),
        updateCheck: GnfpUpdateCheck(fetchJson: (_) async => null),
      ),
    );
    await pumpBoot(tester);
    expect(find.text('GNFPv$kGnfpPackageVersion'), findsOneWidget);
    expect(find.text('GNFPv0.0.1'), findsNothing);
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
    expect(find.text('Network Tip: $expected'), findsOneWidget);
    expect(find.text('Network Tip: …'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('current pin hides the top update line', (tester) async {
    final store = File('${Directory.systemTemp.path}/gnfp-widget-session-current.json');
    if (store.existsSync()) store.deleteSync();
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final http = HttpClient();
    addTearDown(() => http.close(force: true));
    await tester.pumpWidget(
      GnfpWalletApp(
        ledger: GnfpLedger(
          pool: GnfpPoolClient(baseUrl: 'http://127.0.0.1:9', http: http),
        ),
        version: '0.0.5',
        session: GnfpSession(store: store),
        updateCheck: GnfpUpdateCheck(
          fetchJson: (_) async => {
            'tag_name': 'v0.0.5',
            'html_url':
                'https://github.com/rgsneddon/gnfp-wallet/releases/tag/v0.0.5',
            'assets': [
              {
                'name': 'gnfp-wallet-0.0.5-macos.zip',
                'browser_download_url':
                    'https://github.com/rgsneddon/gnfp-wallet/releases/download/v0.0.5/gnfp-wallet-0.0.5-macos.zip',
              },
            ],
          },
        ),
      ),
    );
    await pumpBoot(tester);
    expect(find.byKey(const Key('gnfp-update-banner')), findsNothing);
    expect(find.byKey(const Key('gnfp-update-url')), findsNothing);
    expect(find.byKey(const Key('gnfp-box-identity')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    http.close(force: true);
    await tester.pump();
  });

  testWidgets('credit control is on the facade and uses the two mined-coins phrases', (
    tester,
  ) async {
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
    const seed = 'credit-widget-seed';
    final addr = miner.createAddress(seed: seed);
    wallet.adopt(addr);

    final store = File('${Directory.systemTemp.path}/gnfp-widget-session-credit-shell.json');
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
    await pumpBoot(tester);
    expect(find.byKey(const Key('gnfp-credit-miner')), findsNothing);
    expect(find.text('Credit wallet with pending GNFP'), findsNothing);
    expect(find.text('SOCIAL CHANNELS'), findsOneWidget);
    expect(find.text('DISCORD'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    http.close(force: true);
    await tester.pump();
  });
}
