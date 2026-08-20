import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../gnfp_ledger.dart';
import '../gnfp_owner_ledger.dart';
import '../gnfp_theme.dart';

/// Downloads on desktop; Documents on iOS/Android. Always `.xls`.
File defaultOwnerLedgerExportFile({DateTime? now, String? home}) {
  final stamp = (now ?? DateTime.now())
      .toIso8601String()
      .replaceAll(':', '')
      .replaceAll('-', '')
      .split('.')
      .first;
  final name = 'gnfp-wallet-ledger-$stamp.xls';
  final root = (home ?? Platform.environment['HOME'] ?? '').trim();
  if (Platform.isIOS || Platform.isAndroid) {
    final docs = root.isEmpty ? name : '$root/Documents/$name';
    return File(docs);
  }
  if (root.isNotEmpty) {
    final downloads = Directory('$root/Downloads');
    if (downloads.existsSync()) return File('${downloads.path}/$name');
    return File('$root/$name');
  }
  return File(name);
}

class ExplorerScreen extends StatefulWidget {
  const ExplorerScreen({
    super.key,
    required this.ledger,
    required this.address,
    this.exportFile,
    this.pickExportFile,
  });

  final GnfpLedger ledger;
  final GnfpAddress address;
  final File? exportFile;
  final Future<File?> Function({required String suggestedName})? pickExportFile;

  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _loadBookHistory();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _loadBookHistory();
    });
  }

  @override
  void didUpdateWidget(ExplorerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address.value != widget.address.value) {
      _loadBookHistory();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _loadBookHistory() async {
    await widget.ledger.syncOwnerHistory(widget.address);
    if (mounted) setState(() {});
  }

  List<OwnerLedgerRow> _rows() {
    final live = ownerLedgerNewestFirst(
      ownerLedgerRows(
        address: widget.address.value,
        txs: widget.ledger.transactions,
      ),
    );
    if (live.isNotEmpty) return live;
    final bal = widget.ledger.balance(widget.address);
    if (bal > 0) {
      return [
        OwnerLedgerRow(
          id: 'live-balance',
          kind: 'balance',
          from: '',
          to: widget.address.value,
          amount: bal,
          memo: 'current balance',
        ),
      ];
    }
    return const [];
  }

  Future<void> _exportSpreadsheet() async {
    final rows = _rows();
    if (rows.isEmpty) return;
    final xls = ownerLedgerSpreadsheet(
      address: widget.address.value,
      rows: rows,
    );
    final suggested = defaultOwnerLedgerExportFile().uri.pathSegments.isEmpty
        ? 'gnfp-wallet-ledger.xls'
        : defaultOwnerLedgerExportFile().uri.pathSegments.last;
    final picked = await widget.pickExportFile?.call(suggestedName: suggested);
    var dest = widget.exportFile ?? picked ?? defaultOwnerLedgerExportFile();
    if (!dest.path.toLowerCase().endsWith('.xls')) {
      dest = File('${dest.path}.xls');
    }
    dest.parent.createSync(recursive: true);
    dest.writeAsStringSync(xls);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('gnfp-owner-export-status'),
        content: Text('Saved spreadsheet ${dest.path}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final owner = widget.address.value;
    final rows = _rows();
    final bal = widget.ledger.balance(widget.address);
    final showEmpty = rows.isEmpty && bal <= 0;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Explorer', style: TextStyle(fontSize: 20, color: GnfpTheme.cream)),
          Text(
            'Your full ledger for ${widget.address.value}. Counterparties and amounts are plaintext here only.',
            style: const TextStyle(color: GnfpTheme.neonCyan, fontSize: 12),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('gnfp-owner-export'),
            onPressed: rows.isEmpty ? null : _exportSpreadsheet,
            child: const Text('Export spreadsheet'),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: DecoratedBox(
              key: const Key('gnfp-owner-ledger'),
              decoration: BoxDecoration(
                border: Border.all(color: GnfpTheme.neonCyan.withValues(alpha: 0.35)),
              ),
              child: showEmpty
                  ? const Center(child: Text('No movements on this address yet.'))
                  : Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFF132A4A)),
                            columns: const [
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Id')),
                              DataColumn(label: Text('Kind')),
                              DataColumn(label: Text('From')),
                              DataColumn(label: Text('To')),
                              DataColumn(label: Text('Amount')),
                              DataColumn(label: Text('Asset')),
                              DataColumn(label: Text('Memo')),
                            ],
                            rows: [
                              for (final r in rows)
                                DataRow(
                                  cells: [
                                    DataCell(Text(ownerLedgerRowDate(r), key: Key('gnfp-owner-date-${r.id}'))),
                                    DataCell(Text(r.id, key: Key('gnfp-owner-id-${r.id}'))),
                                    DataCell(
                                      Text(
                                        ownerFacingKind(
                                          address: owner,
                                          from: r.from,
                                          to: r.to,
                                          kind: r.kind,
                                        ),
                                        key: Key('gnfp-owner-kind-${r.id}'),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        ownerFacingParty(owner, r.from),
                                        key: Key('gnfp-owner-from-${r.id}'),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        ownerFacingParty(owner, r.to),
                                        key: Key('gnfp-owner-to-${r.id}'),
                                      ),
                                    ),
                                    DataCell(Text('${r.amount}', key: Key('gnfp-owner-amount-${r.id}'))),
                                    DataCell(Text(r.asset)),
                                    DataCell(Text(r.memo)),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
