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
    'Id,Kind,From,To,Amount,Asset,Memo';

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

/// Spreadsheet (CSV) of the same rows Explorer shows — owner-facing kind
/// and `your address`, newest first. Opens in Excel / Numbers / Sheets.
String ownerLedgerSpreadsheet({
  required String address,
  required Iterable<OwnerLedgerRow> rows,
}) {
  final buf = StringBuffer()..writeln(ownerLedgerSpreadsheetHeader);
  for (final r in rows) {
    buf.writeln(
      [
        r.id,
        ownerFacingKind(address: address, from: r.from, to: r.to, kind: r.kind),
        ownerFacingParty(address, r.from),
        ownerFacingParty(address, r.to),
        r.amount,
        r.asset,
        r.memo,
      ].map(csvCell).join(','),
    );
  }
  return buf.toString();
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
      if (!_involves(addr, from: raw.from, to: raw.to)) continue;
      out.add(OwnerLedgerRow.fromTx(raw));
      continue;
    }
    if (raw is Map) {
      final json = Map<String, dynamic>.from(raw);
      final from = json['from']?.toString() ?? '';
      final to = json['to']?.toString() ?? '';
      if (!_involves(addr, from: from, to: to)) continue;
      out.add(OwnerLedgerRow.fromJson(json));
    }
  }
  return out;
}
