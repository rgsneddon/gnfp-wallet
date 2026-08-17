import 'package:flutter/material.dart';

import '../gnfp_ledger.dart';
import '../gnfp_owner_ledger.dart';
import '../gnfp_theme.dart';

class ExplorerScreen extends StatelessWidget {
  const ExplorerScreen({
    super.key,
    required this.ledger,
    required this.address,
  });

  final GnfpLedger ledger;
  final GnfpAddress address;

  @override
  Widget build(BuildContext context) {
    final rows = ownerLedgerRows(
      address: address.value,
      txs: ledger.transactions,
    ).reversed.toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Explorer', style: TextStyle(fontSize: 20, color: GnfpTheme.cream)),
          Text(
            'Your full ledger for ${address.value}. Counterparties and amounts are plaintext here only.',
            style: const TextStyle(color: GnfpTheme.neonCyan, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: DecoratedBox(
              key: const Key('gnfp-owner-ledger'),
              decoration: BoxDecoration(
                border: Border.all(color: GnfpTheme.neonCyan.withValues(alpha: 0.35)),
              ),
              child: rows.isEmpty
                  ? const Center(child: Text('No movements on this address yet.'))
                  : Scrollbar(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFF132A4A)),
                      columns: const [
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
                              DataCell(Text(r.id, key: Key('gnfp-owner-id-${r.id}'))),
                              DataCell(Text(r.kind)),
                              DataCell(Text(r.from, key: Key('gnfp-owner-from-${r.id}'))),
                              DataCell(Text(r.to)),
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

