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
          'foundAt': 2000,
        },
        {
          'id': 'book-sx',
          'from': owner.value,
          'to': peer,
          'amount': 1,
          'kind': 'send',
          'asset': 'GNFP',
          'memo': 'out',
          'foundAt': 1000,
        },
      ]),
    );
    ledger.adopt(owner);
    expect(ledger.transactions, isEmpty);

    final dest = File(
      '${Directory.systemTemp.path}/gnfp-explorer-export-test.xls',
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
    expect(dest.path.endsWith('.xls'), isTrue);
    final xls = dest.readAsStringSync();
    expect(xls, contains('Excel.Sheet'));
    expect(xls, contains('receive'));
    expect(xls, contains('your address'));
    expect(xls, contains(peer));
    expect(xls.indexOf('book-rx'), lessThan(xls.indexOf('book-sx')));
    expect(find.byKey(const Key('gnfp-owner-export-status')), findsOneWidget);
  });

  testWidgets('positive balance never shows empty-movements copy', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final owner = GnfpLedger().createAddress(seed: 'bal-hist');
    final ledger = GnfpLedger(pool: BookHistoryClient(const []));
    ledger.adopt(owner);
    ledger.rememberSpendable(owner, 4.5);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExplorerScreen(ledger: ledger, address: owner),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('No movements on this address yet.'), findsNothing);
    expect(find.text('4.5'), findsOneWidget);
  });

  testWidgets('new book credit lands newest-first after the explorer poll', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    const peer = 'gnfp1bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    final owner = GnfpLedger().createAddress(seed: 'live-hist');
    final txs = <Map<String, dynamic>>[
      {
        'id': 'old-sx',
        'from': owner.value,
        'to': peer,
        'amount': 1,
        'kind': 'send',
        'foundAt': 1000,
      },
    ];
    final ledger = GnfpLedger(pool: BookHistoryClient(txs));
    ledger.adopt(owner);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExplorerScreen(ledger: ledger, address: owner),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('gnfp-owner-kind-old-sx')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-owner-kind-live-rx')), findsNothing);
    txs.add({
      'id': 'live-rx',
      'from': peer,
      'to': owner.value,
      'amount': 7,
      'kind': 'send',
      'foundAt': 9000,
    });
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.byKey(const Key('gnfp-owner-kind-live-rx')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('gnfp-owner-kind-live-rx'))).data, 'receive');
    expect(
      tester.widget<Text>(find.byKey(const Key('gnfp-owner-amount-live-rx'))).data,
      '7.0',
    );
    expect(find.text('No movements on this address yet.'), findsNothing);
    final liveY = tester.getTopLeft(find.byKey(const Key('gnfp-owner-kind-live-rx'))).dy;
    final oldY = tester.getTopLeft(find.byKey(const Key('gnfp-owner-kind-old-sx'))).dy;
    expect(liveY, lessThan(oldY));
  });

  testWidgets('shipped explorer save-path picker writes .xls to the chosen dest', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    const peer = 'gnfp1bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    final owner = GnfpLedger().createAddress(seed: 'picker-hist');
    final ledger = GnfpLedger(
      pool: BookHistoryClient([
        {
          'id': 'pick-rx',
          'from': peer,
          'to': owner.value,
          'amount': 3,
          'kind': 'send',
          'foundAt': 4000,
        },
      ]),
    );
    ledger.adopt(owner);
    final dest = File('${Directory.systemTemp.path}/gnfp-picker-export.xls');
    if (dest.existsSync()) dest.deleteSync();
    addTearDown(() {
      if (dest.existsSync()) dest.deleteSync();
    });
    String? suggested;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExplorerScreen(
            ledger: ledger,
            address: owner,
            pickExportFile: ({required suggestedName, required bytes}) async {
              suggested = suggestedName;
              return dest;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('gnfp-owner-export')), findsOneWidget);
    await tester.tap(find.byKey(const Key('gnfp-owner-export')));
    await tester.pump();
    expect(suggested, endsWith('.xls'));
    expect(dest.existsSync(), isTrue);
    expect(dest.path.endsWith('.xls'), isTrue);
    expect(dest.readAsStringSync(), contains('Excel.Sheet'));
  });
}
