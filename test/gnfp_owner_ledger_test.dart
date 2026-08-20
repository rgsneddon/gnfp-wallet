import 'package:flutter_test/flutter_test.dart';
import 'package:gnfp_wallet/gnfp_ledger.dart';
import 'package:gnfp_wallet/gnfp_owner_ledger.dart';

void main() {
  test('owner ledger rows are plaintext from/to/amount for one gnfp1', () {
    const owner = 'gnfp1aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const peer = 'gnfp1bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    final rows = ownerLedgerRows(
      address: owner,
      txs: [
        GnfpTx(
          id: 'rx-1',
          from: peer,
          to: owner,
          amount: 12.5,
          kind: 'receive',
          memo: 'from friend',
        ),
        GnfpTx(
          id: 'sx-1',
          from: owner,
          to: peer,
          amount: 1,
          kind: 'send',
        ),
        GnfpTx(
          id: 'mx-1',
          from: 'coinbase',
          to: owner,
          amount: 1,
          kind: 'mine',
        ),
        GnfpTx(
          id: 'other',
          from: peer,
          to: 'gnfp1cccccccccccccccccccccccccccccccccccccccc',
          amount: 99,
          kind: 'send',
        ),
        {
          'id': 'book-1',
          'from': 'gnfp1dddddddddddddddddddddddddddddddddddddddd',
          'to': owner,
          'amount': 3,
          'kind': 'receive',
          'asset': 'GNFP',
          'memo': 'pool',
          'height': 30190,
          'foundAt': 1786987000,
          'jobId': 'gnfp-30190-1',
        },
      ],
    );
    expect(rows.length, 4);
    expect(rows.any((r) => r.id == 'other'), isFalse);
    final recv = rows.firstWhere((r) => r.id == 'rx-1');
    expect(recv.from, peer);
    expect(recv.from.startsWith('shear-'), isFalse);
    expect(recv.to, owner);
    expect(recv.amount, 12.5);
    expect(recv.amount.toString(), isNot('Cfx-hidden'));
    expect(recv.visibleFields['from'], peer);
    expect(recv.visibleFields['amount'], 12.5);
    expect(recv.visibleFields.containsKey('memo'), isTrue);
    final book = rows.firstWhere((r) => r.id == 'book-1');
    expect(book.from, 'gnfp1dddddddddddddddddddddddddddddddddddddddd');
    expect(book.height, 30190);
    expect(book.foundAt, 1786987000);
    expect(book.jobId, 'gnfp-30190-1');
    expect(book.visibleFields.keys, containsAll(['id', 'kind', 'from', 'to', 'amount', 'asset']));
    expect(jsonCloakFree(rows), isTrue);
  });

  test('owner-facing kind is receive when this wallet is the destination', () {
    const owner = 'gnfp1aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const peer = 'gnfp1bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    expect(
      ownerFacingKind(address: owner, from: peer, to: owner, kind: 'send'),
      'receive',
    );
    expect(
      ownerFacingKind(address: owner, from: owner, to: peer, kind: 'send'),
      'send',
    );
    expect(
      ownerFacingKind(address: owner, from: 'coinbase', to: owner, kind: 'mine'),
      'receive',
    );
    expect(ownerFacingParty(owner, owner), ownerAddressLabel);
    expect(ownerFacingParty(owner, peer), peer);
  });

  test('owner ledger spreadsheet is CSV with your address and receive/send', () {
    const owner = 'gnfp1aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const peer = 'gnfp1bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    final rows = ownerLedgerRows(
      address: owner,
      txs: [
        GnfpTx(
          id: 'rx-1',
          from: peer,
          to: owner,
          amount: 12.5,
          kind: 'send',
          memo: 'from friend, quoted',
        ),
        GnfpTx(
          id: 'sx-1',
          from: owner,
          to: peer,
          amount: 1,
          kind: 'send',
        ),
      ],
    ).reversed.toList();
    final xls = ownerLedgerSpreadsheet(address: owner, rows: rows);
    expect(xls, contains('Excel.Sheet'));
    expect(xls, contains('receive'));
    expect(xls, contains(ownerAddressLabel));
    expect(xls, contains(peer));
    expect(xls, contains('from friend, quoted'));
    expect(xls.contains(owner), isFalse);
    expect(xls.indexOf('sx-1'), lessThan(xls.indexOf('rx-1')));
  });
}

bool jsonCloakFree(List<OwnerLedgerRow> rows) {
  final blob = rows.map((r) => r.visibleFields.toString()).join();
  return !blob.contains('Cfx-hidden') && !blob.contains('shear-');
}
