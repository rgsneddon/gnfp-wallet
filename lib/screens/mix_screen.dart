import 'package:flutter/material.dart';

import '../copyable_address.dart';
import '../gnfp_bridge.dart';
import '../gnfp_ledger.dart';
import '../gnfp_theme.dart';

/// One-screen mix: pick two coins, amount, go. Sidechain lock+mint under it.
class MixScreen extends StatefulWidget {
  const MixScreen({super.key, required this.mixer, required this.gnfpAddress});

  final RpMixer mixer;
  final GnfpAddress gnfpAddress;

  @override
  State<MixScreen> createState() => _MixScreenState();
}

class _MixScreenState extends State<MixScreen> {
  String fromCoin = 'PERC';
  String toCoin = 'GNFP';
  final amt = TextEditingController(text: '1');
  String status = '';

  @override
  void dispose() {
    amt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final perc = widget.mixer.books['PERC']?.of('perc-pocket') ?? 0;
    final gnfp = widget.mixer.gnfp.balance(widget.gnfpAddress);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Mix coins', style: TextStyle(fontSize: 20, color: GnfpTheme.cream)),
        const Text(
          'Mix cannot mint GNFP. Spendable GNFP only arrives from a peer send '
          'or miner redeem.',
        ),
        const SizedBox(height: 12),
        Text('PERC pocket $perc'),
        CopyableAddress(
          key: const Key('gnfp-mix-address'),
          address: widget.gnfpAddress.value,
          label: 'GNFP',
        ),
        Text('GNFP balance $gnfp', key: const Key('gnfp-mix-balance')),
        DropdownButton<String>(
          key: const Key('gnfp-mix-from'),
          value: fromCoin,
          items: rpMixableCoins
              .map((c) => DropdownMenuItem(value: c, child: Text('From $c')))
              .toList(),
          onChanged: (v) => setState(() => fromCoin = v ?? fromCoin),
        ),
        DropdownButton<String>(
          key: const Key('gnfp-mix-to'),
          value: toCoin,
          items: rpMixableCoins
              .map((c) => DropdownMenuItem(value: c, child: Text('To $c')))
              .toList(),
          onChanged: (v) => setState(() => toCoin = v ?? toCoin),
        ),
        TextField(
          key: const Key('gnfp-mix-amount'),
          controller: amt,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount'),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: const BoxDecoration(gradient: GnfpTheme.accentGradient),
          child: FilledButton(
            key: const Key('gnfp-mix-go'),
            style: FilledButton.styleFrom(backgroundColor: Colors.transparent),
            onPressed: () async {
              try {
                final fromAddr = fromCoin == 'GNFP' ? widget.gnfpAddress.value : 'perc-pocket';
                final toAddr = toCoin == 'GNFP' ? widget.gnfpAddress.value : 'perc-pocket';
                await widget.mixer.mix(
                  fromCoin: fromCoin,
                  toCoin: toCoin,
                  fromAddress: fromAddr,
                  toAddress: toAddr,
                  amount: double.parse(amt.text),
                );
                setState(() => status = 'mixed $fromCoin → $toCoin');
              } catch (e) {
                setState(() => status = e.toString());
              }
            },
            child: const Text('Mix'),
          ),
        ),
        Text(status, key: const Key('gnfp-mix-status')),
      ],
    );
  }
}
