import 'package:flutter/material.dart';

import '../gnfp_ledger.dart';
import '../gnfp_theme.dart';

class ExplorerScreen extends StatelessWidget {
  const ExplorerScreen({super.key, required this.ledger});

  final GnfpLedger ledger;

  @override
  Widget build(BuildContext context) {
    final txs = ledger.transactions.toList().reversed.toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Explorer', style: TextStyle(fontSize: 20, color: GnfpTheme.cream)),
        Text('Pool $gnfpPoolUrl · $gnfpStratum'),
        ...txs.map(
          (t) => ListTile(
            title: Text('${t.kind} ${t.amount} $gnfpTicker'),
            subtitle: Text('${t.from} → ${t.to}'),
          ),
        ),
      ],
    );
  }
}
