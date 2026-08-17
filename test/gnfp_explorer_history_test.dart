import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnfp_wallet/gnfp_ledger.dart';
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
          'kind': 'receive',
          'asset': 'GNFP',
          'memo': 'from friend',
          'height': 30190,
        },
      ]),
    );
    ledger.adopt(owner);
    expect(ledger.transactions, isEmpty);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExplorerScreen(ledger: ledger, address: owner),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('gnfp-owner-ledger')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-owner-from-book-rx')), findsOneWidget);
    expect(find.text(peer), findsOneWidget);
    expect(find.text('12.5'), findsOneWidget);
    expect(find.text(owner.value), findsWidgets);
    expect(find.textContaining('Cfx-hidden'), findsNothing);
    expect(find.textContaining('shear-'), findsNothing);
    expect(find.text('No movements on this address yet.'), findsNothing);
  });
}
