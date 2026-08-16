import 'package:flutter/material.dart';

import '../copyable_address.dart';
import '../gnfp_ledger.dart';
import '../gnfp_theme.dart';

class CreditScreen extends StatefulWidget {
  const CreditScreen({super.key, required this.ledger, required this.address});

  final GnfpLedger ledger;
  final GnfpAddress address;

  @override
  State<CreditScreen> createState() => _CreditScreenState();
}

class _CreditScreenState extends State<CreditScreen> {
  String status = '';
  double? minerBook;

  @override
  void initState() {
    super.initState();
    _pullMinerBook();
  }

  Future<void> _pullMinerBook() async {
    try {
      final n = await widget.ledger.pool.balance(widget.address.value);
      if (!mounted) return;
      setState(() => minerBook = n);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Credit', style: TextStyle(fontSize: 20, color: GnfpTheme.cream)),
        const Text(
          'Redeem miner rewards already earned by this gnfp1 address. '
          'There is no faucet and no self-mint.',
        ),
        CopyableAddress(address: widget.address.value),
        FilledButton(
          key: const Key('gnfp-credit-miner'),
          onPressed: () async {
            try {
              final tx = await widget.ledger.creditFromMiner(to: widget.address);
              setState(() {
                status = tx.amount > 0
                    ? 'credited from your miner +${tx.amount} $gnfpTicker'
                    : 'miner book already in wallet';
              });
              await _pullMinerBook();
            } catch (e) {
              setState(() => status = e.toString());
            }
          },
          child: const Text('Credit from your miner'),
        ),
        Text(
          'Miner book ${minerBook ?? '…'} $gnfpTicker',
          key: const Key('gnfp-credit-miner-book'),
        ),
        Text('Balance ${widget.ledger.balance(widget.address)} $gnfpTicker',
            key: const Key('gnfp-credit-balance')),
        Text(status, key: const Key('gnfp-credit-status')),
      ],
    );
  }
}
