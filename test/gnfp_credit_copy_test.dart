import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnfp_wallet/gnfp_ledger.dart';
import 'package:gnfp_wallet/gnfp_pool_client.dart';
import 'package:gnfp_wallet/gnfp_session.dart';
import 'package:gnfp_wallet/gnfp_social.dart';
import 'package:gnfp_wallet/gnfp_update.dart';
import 'package:gnfp_wallet/main.dart';
import 'package:gnfp_wallet/screens/wallet_screen.dart';

void main() {
  test('social launch map is Discord / Telegram / BitcoinTalk only', () {
    expect(gnfpSocialLaunchUri('DISCORD').toString(), 'https://discord.com/invite/H9TdGyCUCa');
    expect(gnfpSocialLaunchUri('TELEGRAM').toString(), 'https://t.me/gnfpchat');
    expect(
      gnfpSocialLaunchUri('BitcoinTalk').toString(),
      'https://bitcointalk.org/index.php?topic=5591310',
    );
    expect(gnfpSocialChannels.length, 3);
  });

  testWidgets('wallet tab has social titles and no pending-credit control', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final opened = <Uri>[];
    final ledger = GnfpLedger();
    final addr = ledger.createAddress(seed: 'social-tab');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WalletScreen(
            ledger: ledger,
            address: addr,
            version: '0.1.7',
            openExternal: (url) async {
              opened.add(url);
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Credit wallet with pending GNFP'), findsNothing);
    expect(find.byKey(const Key('gnfp-credit-miner')), findsNothing);
    expect(find.text('SOCIAL CHANNELS'), findsOneWidget);
    expect(find.text('DISCORD'), findsOneWidget);
    expect(find.text('TELEGRAM'), findsOneWidget);
    expect(find.text('BitcoinTalk'), findsOneWidget);
    expect(find.textContaining('https://'), findsNothing);
    expect(find.textContaining('discord.com'), findsNothing);
    expect(find.textContaining('t.me/'), findsNothing);
    expect(find.textContaining('bitcointalk.org'), findsNothing);
    await tester.tap(find.byKey(const Key('gnfp-social-DISCORD')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('gnfp-social-TELEGRAM')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('gnfp-social-BitcoinTalk')));
    await tester.pump();
    expect(opened.map((u) => u.toString()).toList(), [
      'https://discord.com/invite/H9TdGyCUCa',
      'https://t.me/gnfpchat',
      'https://bitcointalk.org/index.php?topic=5591310',
    ]);
  });

  testWidgets('shell wallet tab still boots without credit', (tester) async {
    final store = File('${Directory.systemTemp.path}/gnfp-widget-session-social.json');
    store.writeAsStringSync(
      jsonEncode({'seed': 'social-shell', 'address': GnfpLedger().createAddress(seed: 'social-shell').value, 'schema': 2}),
    );
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      GnfpWalletApp(
        ledger: GnfpLedger(),
        version: '0.1.7',
        session: GnfpSession(store: store),
        updateCheck: GnfpUpdateCheck(fetchJson: (_) async => null),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Credit wallet with pending GNFP'), findsNothing);
    expect(find.text('SOCIAL CHANNELS'), findsOneWidget);
  });
}
