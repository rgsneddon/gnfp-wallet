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

bool _involves(String address, {required String from, required String to}) {
  return from == address || to == address;
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
