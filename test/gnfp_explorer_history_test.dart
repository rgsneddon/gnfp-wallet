import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnfp_wallet/gnfp_ledger.dart';
import 'package:gnfp_wallet/gnfp_owner_ledger.dart';
import 'package:gnfp_wallet/gnfp_pool_client.dart';
import 'package:gnfp_wallet/screens/explorer_screen.dart';

/// Book-shaped /api/wallet/history client. Drives the real get() path.
class BookHistoryClient extends GnfpPoolClient {
  BookHistoryClient(this.txs);

  final List<Map<String, dynamic>> txs;

  @override
  Future<Map<String, dynamic>> get(String path) async {
    if (!path.contains('/wallet/history')) {
      return {'ok': true};
    }
    return {'ok': true, 'coin': 'GNFP', 'txs': txs};
  }
}

void main() {
  testWidgets('Explorer table shows book history From/To/Amount plaintext', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    const peer = 'gnfp1bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    final owner = GnfpLedger().createAddress(seed: 'explorer-book-hist');
    final ledger = GnfpLedger(
      pool: BookHistoryClient([
        {
          'id': 'book-rx',
          'from': peer,
          'to': owner.value,
          'amount': 12.5,
          'kind': 'send',
          'asset': 'GNFP',
          'memo': 'from friend',
          'height': 30190,
        },
        {
          'id': 'book-sx',
          'from': owner.value,
          'to': peer,
          'amount': 1,
          'kind': 'send',
          'asset': 'GNFP',
          'memo': 'out',
        },
      ]),
    );
    ledger.adopt(owner);
    expect(ledger.transactions, isEmpty);

    final dest = File(
      '${Directory.systemTemp.path}/gnfp-explorer-export-test.csv',
    );
    if (dest.existsSync()) dest.deleteSync();
    addTearDown(() {
      if (dest.existsSync()) dest.deleteSync();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExplorerScreen(
            ledger: ledger,
            address: owner,
            exportFile: dest,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('gnfp-owner-ledger')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-owner-from-book-rx')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-owner-kind-book-rx')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('gnfp-owner-kind-book-rx'))).data, 'receive');
    expect(tester.widget<Text>(find.byKey(const Key('gnfp-owner-to-book-rx'))).data, 'your address');
    expect(tester.widget<Text>(find.byKey(const Key('gnfp-owner-from-book-rx'))).data, peer);
    expect(tester.widget<Text>(find.byKey(const Key('gnfp-owner-kind-book-sx'))).data, 'send');
    expect(tester.widget<Text>(find.byKey(const Key('gnfp-owner-from-book-sx'))).data, 'your address');
    expect(tester.widget<Text>(find.byKey(const Key('gnfp-owner-to-book-sx'))).data, peer);
    expect(find.text(peer), findsWidgets);
    expect(find.text('12.5'), findsOneWidget);
    expect(find.text('your address'), findsWidgets);
    expect(find.textContaining('Cfx-hidden'), findsNothing);
    expect(find.textContaining('shear-'), findsNothing);
    expect(find.text('No movements on this address yet.'), findsNothing);
    expect(find.byKey(const Key('gnfp-owner-export')), findsOneWidget);
    await tester.tap(find.byKey(const Key('gnfp-owner-export')));
    await tester.pump();
    expect(dest.existsSync(), isTrue);
    final csv = dest.readAsStringSync();
    expect(csv, startsWith(ownerLedgerSpreadsheetHeader));
    expect(csv, contains('receive'));
    expect(csv, contains('your address'));
    expect(csv, contains(peer));
    expect(find.byKey(const Key('gnfp-owner-export-status')), findsOneWidget);
  });
}
