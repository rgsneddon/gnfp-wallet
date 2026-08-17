import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../gnfp_in_wallet_miner.dart';
import '../gnfp_ledger.dart';
import '../gnfp_mine_command.dart';
import '../gnfp_theme.dart';

/// Mine tab: auto-filled gnfp-mine 1.0.8 line + MINE GNFP starts in-wallet hashing.
class MineScreen extends StatefulWidget {
  const MineScreen({
    super.key,
    required this.address,
    this.miner,
  });

  final GnfpAddress address;
  final InWalletMiner? miner;

  @override
  State<MineScreen> createState() => _MineScreenState();
}

class _MineScreenState extends State<MineScreen> {
  late final InWalletMiner miner = widget.miner ?? InWalletMiner();
  StreamSubscription<InWalletMinerStatus>? _sub;
  InWalletMinerStatus status = const InWalletMinerStatus();
  int threads = gnfpMineDefaultThreads;

  WalletMineCommand? get cmd => buildWalletMineCommand(
        address: widget.address.value,
        threads: threads,
      );

  @override
  void initState() {
    super.initState();
    _sub = miner.updates.listen((s) {
      if (mounted) setState(() => status = s);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (widget.miner == null) miner.stop();
    super.dispose();
  }

  Future<void> _toggle() async {
    final built = cmd;
    if (built == null) return;
    if (status.running) {
      await miner.stop();
      return;
    }
    await miner.start(built);
  }

  @override
  Widget build(BuildContext context) {
    final built = cmd;
    final line = built?.command ?? '';
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
          const SizedBox(height: 8),
          const Text(
            'gnfp-mine 1.0.8 · TLS to the Germany book. Credit lands on this wallet.',
            style: TextStyle(color: GnfpTheme.neonCyan),
          ),
          const SizedBox(height: 12),
          SelectableText(
            line,
            key: const Key('gnfp-miner-cmd'),
            style: const TextStyle(color: GnfpTheme.neonLime, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(
                key: const Key('gnfp-mine-copy'),
                onPressed: line.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: line));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Miner command copied')),
                        );
                      },
                child: const Text('Copy miner command'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                key: const Key('gnfp-mine-start'),
                onPressed: built == null ? null : _toggle,
                child: Text(status.running ? 'STOP' : 'MINE GNFP'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            status.running
                ? 'hashing as ${status.user} · ${status.hashrate.toStringAsFixed(1)} H/s · accepted ${status.accepted}'
                : 'idle',
            key: const Key('gnfp-mine-status'),
            style: const TextStyle(color: GnfpTheme.cream),
          ),
        ],
      ),
    );
  }
}
