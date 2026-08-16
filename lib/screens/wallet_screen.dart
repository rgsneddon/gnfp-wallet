import 'dart:async';

import 'package:flutter/material.dart';

import '../copyable_address.dart';
import '../gnfp_ledger.dart';
import '../gnfp_qr.dart';
import '../gnfp_theme.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({
    super.key,
    required this.ledger,
    required this.address,
  });

  final GnfpLedger ledger;
  final GnfpAddress address;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final toCtrl = TextEditingController();
  final amtCtrl = TextEditingController();
  String status = '';
  double? networkBal;
  int? networkTip;
  Timer? _poll;
  Timer? _retry;

  String get minerCommand =>
      'perc-mine --pool $gnfpStratum --user ${widget.address.value} --coin GNFP --notls';

  @override
  void initState() {
    super.initState();
    networkTip = widget.ledger.lastTip;
    _pullNetwork();
    _retry = Timer(const Duration(milliseconds: 400), () {
      if (mounted && networkTip == null) _pullNetwork();
    });
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      _pullNetwork();
    });
  }

  Future<void> _pullNetwork() async {
    try {
      final n = await widget.ledger.pool.balance(widget.address.value);
      if (mounted) setState(() => networkBal = n);
    } catch (_) {}
    try {
      final tip = await widget.ledger.networkTip();
      if (mounted) setState(() => networkTip = tip);
    } catch (_) {}
  }

  @override
  void dispose() {
    _poll?.cancel();
    _retry?.cancel();
    toCtrl.dispose();
    amtCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bal = widget.ledger.balance(widget.address);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Wallet', style: TextStyle(fontSize: 20, color: GnfpTheme.cream)),
        Text('Balance ${networkBal ?? bal} $gnfpTicker', key: const Key('gnfp-balance')),
        Text(
          'Network tip ${networkTip ?? '…'}',
          key: const Key('gnfp-network-tip'),
        ),
        CopyableAddress(
          key: const Key('gnfp-address'),
          address: widget.address.value,
        ),
        GnfpQr(address: widget.address),
        TextField(
          key: const Key('gnfp-send-to'),
          controller: toCtrl,
          decoration: const InputDecoration(labelText: 'Send to GNFP address'),
        ),
        TextField(
          key: const Key('gnfp-send-amount'),
          controller: amtCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount GNFP'),
        ),
        FilledButton(
          key: const Key('gnfp-send'),
          onPressed: () async {
            try {
              await widget.ledger.send(
                from: widget.address,
                to: GnfpAddress(toCtrl.text.trim()),
                amount: double.parse(amtCtrl.text),
              );
              setState(() => status = 'sent');
            } catch (e) {
              setState(() => status = e.toString());
            }
          },
          child: const Text('Send'),
        ),
        const Text(
          'Incoming GNFP only arrives when another gnfp1 wallet sends here, '
          'or when you redeem miner rewards on Credit.',
          key: Key('gnfp-receive-hint'),
        ),
        Text(minerCommand, key: const Key('gnfp-miner-cmd')),
        Text(status, key: const Key('gnfp-wallet-status')),
      ],
    );
  }
}
