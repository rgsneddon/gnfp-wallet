/// Owner-only ledger projection. This wallet surface is the only place that
/// shows plaintext counterparties and amounts. Public pool/explorer stay cloaked.
library;

import 'gnfp_ledger.dart';

const ownerLedgerColumns = <String>[
  'id',
  'kind',
  'from',
  'to',
  'amount',
  'asset',
  'memo',
  'height',
  'foundAt',
  'jobId',
];

class OwnerLedgerRow {
  const OwnerLedgerRow({
    required this.id,
    required this.kind,
    required this.from,
    required this.to,
    required this.amount,
    this.asset = gnfpTicker,
    this.memo = '',
    this.height,
    this.foundAt,
    this.jobId,
  });

  final String id;
  final String kind;
  final String from;
  final String to;
  final double amount;
  final String asset;
  final String memo;
  final int? height;
  final int? foundAt;
  final String? jobId;

  Map<String, Object?> get visibleFields {
    return {
      'id': id,
      'kind': kind,
      'from': from,
      'to': to,
      'amount': amount,
      'asset': asset,
      if (memo.isNotEmpty) 'memo': memo,
      if (height != null) 'height': height,
      if (foundAt != null) 'foundAt': foundAt,
      if (jobId != null && jobId!.isNotEmpty) 'jobId': jobId,
    };
  }

  factory OwnerLedgerRow.fromTx(GnfpTx tx, {Map<String, dynamic>? extra}) {
    final row = extra ?? {};
    return OwnerLedgerRow(
      id: tx.id,
      kind: tx.kind,
      from: tx.from,
      to: tx.to,
      amount: tx.amount,
      asset: row['asset']?.toString() ?? gnfpTicker,
      memo: tx.memo,
      height: (row['height'] as num?)?.toInt(),
      foundAt: (row['foundAt'] as num?)?.toInt(),
      jobId: row['jobId']?.toString(),
    );
  }

  factory OwnerLedgerRow.fromJson(Map<String, dynamic> json) {
    return OwnerLedgerRow(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      asset: json['asset']?.toString() ?? gnfpTicker,
      memo: json['memo']?.toString() ?? '',
      height: (json['height'] as num?)?.toInt(),
      foundAt: (json['foundAt'] as num?)?.toInt(),
      jobId: json['jobId']?.toString(),
    );
  }
}

const ownerAddressLabel = 'your address';

bool _involves(String address, {required String from, required String to}) {
  return from == address || to == address;
}

/// Unconfirmed hash micros stay off the explorer. User send/receive for
/// this gnfp1 stay (pending sends are still this address's movements).
bool ownerHistoryVisible(dynamic tx) {
  if (tx is GnfpTx) {
    if (tx.kind == 'hash' && tx.confirmed != true) return false;
    return true;
  }
  if (tx is Map) {
    final kind = tx['kind']?.toString() ?? '';
    final confirmed = tx['confirmed'];
    if (kind == 'hash' && confirmed != true) return false;
    if (kind == 'hash' && confirmed == false) return false;
    return true;
  }
  return true;
}

/// Book history often stores every movement as `send`. Show direction
/// relative to [address] so incoming credit is receive, outgoing is send.
String ownerFacingKind({
  required String address,
  required String from,
  required String to,
  String kind = '',
}) {
  if (to == address && from != address) return 'receive';
  if (from == address && to != address) return 'send';
  if (from == address && to == address) return 'send';
  if (kind.isEmpty) return 'send';
  return kind;
}

/// Own gnfp1 is shown as [ownerAddressLabel] so send vs receive is readable.
String ownerFacingParty(String address, String party) {
  if (party.isEmpty) return party;
  return party == address ? ownerAddressLabel : party;
}

const ownerLedgerSpreadsheetHeader =
    'Date,Id,Kind,From,To,Amount,Asset,Memo';

String csvCell(Object? value) {
  final text = value?.toString() ?? '';
  if (text.contains(',') ||
      text.contains('"') ||
      text.contains('\n') ||
      text.contains('\r')) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}

String ownerLedgerRowDate(OwnerLedgerRow row) {
  final ms = row.foundAt;
  if (ms == null || ms <= 0) {
    return row.height != null ? 'height ${row.height}' : '';
  }
  return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();
}

int ownerLedgerRecency(OwnerLedgerRow row) {
  if (row.foundAt != null && row.foundAt! > 0) return row.foundAt!;
  if (row.height != null) return row.height! * 1000;
  return 0;
}

/// Newest first (foundAt / height). Stable id tie-break.
List<OwnerLedgerRow> ownerLedgerNewestFirst(Iterable<OwnerLedgerRow> rows) {
  final out = rows.toList();
  out.sort((a, b) {
    final c = ownerLedgerRecency(b).compareTo(ownerLedgerRecency(a));
    if (c != 0) return c;
    return b.id.compareTo(a.id);
  });
  return out;
}

String _xlsCell(Object? value) {
  final text = (value?.toString() ?? '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  return '<Cell><Data ss:Type="String">$text</Data></Cell>';
}

/// Excel SpreadsheetML saved as `.xls` — same rows Explorer shows.
String ownerLedgerSpreadsheet({
  required String address,
  required Iterable<OwnerLedgerRow> rows,
}) {
  final ordered = ownerLedgerNewestFirst(rows);
  final buf = StringBuffer()
    ..writeln('<?xml version="1.0"?>')
    ..writeln('<?mso-application progid="Excel.Sheet"?>')
    ..writeln(
      '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" '
      'xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">',
    )
    ..writeln('<Worksheet ss:Name="GNFP"><Table>')
    ..writeln(
      '<Row>${['Date', 'Id', 'Kind', 'From', 'To', 'Amount', 'Asset', 'Memo'].map(_xlsCell).join()}</Row>',
    );
  for (final r in ordered) {
    buf.writeln(
      '<Row>${[
        ownerLedgerRowDate(r),
        r.id,
        ownerFacingKind(address: address, from: r.from, to: r.to, kind: r.kind),
        ownerFacingParty(address, r.from),
        ownerFacingParty(address, r.to),
        r.amount,
        r.asset,
        r.memo,
      ].map(_xlsCell).join()}</Row>',
    );
  }
  buf.writeln('</Table></Worksheet></Workbook>');
  return buf.toString();
}

/// Two ownership checks: gnfp1 match plus shear-obfuscation at that tx height.
bool ownsLedgerTx({
  required String address,
  required String shear,
  required dynamic tx,
}) {
  final addr = address.trim();
  if (addr.isEmpty || tx == null) return false;
  String from;
  String to;
  String storedFrom;
  String storedTo;
  if (tx is GnfpTx) {
    from = tx.from;
    to = tx.to;
    storedFrom = '';
    storedTo = '';
  } else if (tx is Map) {
    from = tx['from']?.toString() ?? '';
    to = tx['to']?.toString() ?? '';
    storedFrom = tx['shearFrom']?.toString() ?? '';
    storedTo = tx['shearTo']?.toString() ?? '';
  } else {
    return false;
  }
  final involved = from == addr || to == addr;
  if (!involved) return false;
  final want = shear.trim();
  if (want.isEmpty) return true;
  final stored = from == addr ? storedFrom : storedTo;
  return stored == want || storedFrom == want || storedTo == want;
}

/// Honest spendable from height-ordered txs. Live 0 is not applied here.
double reconstructSpendable({
  required String address,
  required String shear,
  required Iterable<dynamic> txs,
}) {
  final addr = address.trim();
  if (addr.isEmpty) return 0;
  final rows = txs.toList();
  rows.sort((a, b) {
    int heightOf(dynamic t) {
      if (t is Map) return (t['height'] as num?)?.toInt() ?? 0;
      return 0;
    }

    final d = heightOf(a).compareTo(heightOf(b));
    if (d != 0) return d;
    String idOf(dynamic t) {
      if (t is GnfpTx) return t.id;
      if (t is Map) return t['id']?.toString() ?? '';
      return '';
    }

    return idOf(a).compareTo(idOf(b));
  });
  var bal = 0.0;
  for (final tx in rows) {
    if (!ownsLedgerTx(address: addr, shear: shear, tx: tx)) continue;
    if (tx is GnfpTx) {
      if (tx.to == addr) bal += tx.amount;
      if (tx.from == addr) bal -= tx.amount;
      continue;
    }
    if (tx is Map) {
      final amt = (tx['amount'] as num?)?.toDouble() ?? 0;
      if ((tx['to']?.toString() ?? '') == addr) bal += amt;
      if ((tx['from']?.toString() ?? '') == addr) bal -= amt;
    }
  }
  return bal;
}

/// Full plaintext ledger for [address] only. Never shear-tags or Cfx-hidden.
List<OwnerLedgerRow> ownerLedgerRows({
  required String address,
  required Iterable<dynamic> txs,
}) {
  final addr = address.trim();
  if (addr.isEmpty) return const [];
  final out = <OwnerLedgerRow>[];
  for (final raw in txs) {
    if (raw is GnfpTx) {
      if (!ownerHistoryVisible(raw)) continue;
      if (!_involves(addr, from: raw.from, to: raw.to)) continue;
      if (raw.amount <= 0) continue;
      out.add(OwnerLedgerRow.fromTx(raw, extra: {
        if (raw.height != null) 'height': raw.height,
        if (raw.foundAt != null) 'foundAt': raw.foundAt,
      }));
      continue;
    }
    if (raw is Map) {
      final json = Map<String, dynamic>.from(raw);
      if (!ownerHistoryVisible(json)) continue;
      final from = json['from']?.toString() ?? '';
      final to = json['to']?.toString() ?? '';
      if (!_involves(addr, from: from, to: to)) continue;
      if (((json['amount'] as num?)?.toDouble() ?? 0) <= 0) continue;
      out.add(OwnerLedgerRow.fromJson(json));
    }
  }
  return out;
}
