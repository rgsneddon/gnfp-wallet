import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../gnfp_ledger.dart';
import '../gnfp_theme.dart';

/// First Mine tab. Hosts the miner command; it does not live on the wallet facade.
class MineScreen extends StatelessWidget {
  const MineScreen({super.key, required this.address});

  final GnfpAddress address;

  String get minerCommand =>
      'gnfp-mine --pool $gnfpStratum --user ${address.value}.worker --threads 1';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mine',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: GnfpTheme.cream,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'CPU miner for this perpetual gnfp1. One thread unless you change it.',
            style: const TextStyle(color: GnfpTheme.neonCyan),
          ),
          const SizedBox(height: 12),
          SelectableText(
            minerCommand,
            key: const Key('gnfp-miner-cmd'),
            style: const TextStyle(color: GnfpTheme.neonLime, fontSize: 13),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('gnfp-mine-copy'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: minerCommand));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Miner command copied')),
              );
            },
            child: const Text('Copy miner command'),
          ),
        ],
      ),
    );
  }
}
