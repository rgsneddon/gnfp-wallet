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
    required this.version,
  });

  final GnfpLedger ledger;
  final GnfpAddress address;
  final String version;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final toCtrl = TextEditingController();
  final amtCtrl = TextEditingController();
  String status = '';
  String creditStatus = '';
  double? networkBal;
  int? networkTip;
  bool showQr = false;
  Timer? _poll;
  Timer? _retry;

  static String formatBalance(double value) => value.toStringAsFixed(8);

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

  Future<void> _creditPending() async {
    try {
      final tx = await widget.ledger.creditFromMiner(to: widget.address);
      if (!mounted) return;
      setState(() {
        creditStatus = tx.amount > 0
            ? 'credited from your miner +${tx.amount} $gnfpTicker'
            : 'miner book already in wallet';
      });
      await _pullNetwork();
    } catch (e) {
      if (!mounted) return;
      setState(() => creditStatus = e.toString());
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _retry?.cancel();
    toCtrl.dispose();
    amtCtrl.dispose();
    super.dispose();
  }

  Widget _box({required Key key, required Widget child}) {
    return Expanded(
      child: Container(
        key: key,
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: GnfpTheme.blackCard,
          borderRadius: BorderRadius.circular(GnfpTheme.radius),
          border: Border.all(color: const Color(0xFF222222)),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bal = networkBal ?? widget.ledger.balance(widget.address);
    return Column(
      key: const Key('gnfp-wallet-facade'),
      children: [
        _box(
          key: const Key('gnfp-box-identity'),
          child: Row(
            children: [
              Image.asset(
                'assets/logo.png',
                key: const Key('gnfp-logo'),
                height: 56,
                width: 56,
                filterQuality: FilterQuality.medium,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'GNFP Wallet',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      color: GnfpTheme.cream,
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    'GNFPv${widget.version}',
                    key: const Key('gnfp-version'),
                    style: const TextStyle(
                      fontSize: 14,
                      color: GnfpTheme.neonCyan,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _box(
          key: const Key('gnfp-box-holdings'),
          child: ListView(
            children: [
              Text(
                'Balance: ${formatBalance(bal)} $gnfpTicker',
                key: const Key('gnfp-balance'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: GnfpTheme.neonLime,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Network Tip: ${networkTip ?? '…'}',
                key: const Key('gnfp-network-tip'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: GnfpTheme.neonYellow,
                ),
              ),
              const SizedBox(height: 8),
              CopyableAddress(
                key: const Key('gnfp-address'),
                address: widget.address.value,
                label: 'Address:',
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('gnfp-show-qr'),
                  onPressed: () => setState(() => showQr = !showQr),
                  child: Text(
                    showQr ? 'hide QR code' : 'show QR code',
                    style: const TextStyle(color: GnfpTheme.neonCyan),
                  ),
                ),
              ),
              if (showQr) GnfpQr(address: widget.address),
            ],
          ),
        ),
        _box(
          key: const Key('gnfp-box-send'),
          child: ListView(
            children: [
              TextField(
                key: const Key('gnfp-send-to'),
                controller: toCtrl,
                style: const TextStyle(color: GnfpTheme.cream),
                decoration: const InputDecoration(labelText: 'Send to GNFP address'),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('gnfp-send-amount'),
                controller: amtCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: GnfpTheme.cream),
                decoration: const InputDecoration(labelText: 'Amount GNFP'),
              ),
              const SizedBox(height: 10),
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
                    await _pullNetwork();
                  } catch (e) {
                    setState(() => status = e.toString());
                  }
                },
                child: const Text('Send'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('gnfp-credit-miner'),
                onPressed: _creditPending,
                child: const Text('Credit wallet with pending GNFP'),
              ),
              Text(status, key: const Key('gnfp-wallet-status')),
              Text(creditStatus, key: const Key('gnfp-credit-status')),
            ],
          ),
        ),
      ],
    );
  }
}
