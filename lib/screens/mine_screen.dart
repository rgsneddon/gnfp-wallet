import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../gnfp_in_wallet_miner.dart';
import '../gnfp_ledger.dart';
import '../gnfp_mine_command.dart';
import '../gnfp_theme.dart';

/// Mine tab: auto-filled gnfp-mine 1.0.9 line + MINE GNFP starts in-wallet hashing.
class MineScreen extends StatefulWidget {
  const MineScreen({
    super.key,
    required this.address,
    this.miner,
    this.processors,
    this.allowMining = true,
  });

  final GnfpAddress address;
  final InWalletMiner? miner;
  final int? processors;
  final bool allowMining;

  @override
  State<MineScreen> createState() => _MineScreenState();
}

class _MineScreenState extends State<MineScreen> {
  late final InWalletMiner miner = widget.miner ?? InWalletMiner();
  StreamSubscription<InWalletMinerStatus>? _sub;
  late InWalletMinerStatus status = miner.status;
  late final TextEditingController payoutCtrl;
  int threads = gnfpMineDefaultThreads;
  GnfpMinePool pool = gnfpMinePools.first;

  int get maxThreads => gnfpMineMaxThreads(processors: widget.processors);
  List<int> get threadChoices =>
      gnfpMineThreadChoicesFor(processors: widget.processors);

  WalletMineCommand? get cmd => buildWalletMineCommand(
        address: payoutCtrl.text,
        pool: pool.hostPort,
        threads: threads,
        tls: pool.tls,
        processors: widget.processors,
      );

  @override
  void initState() {
    super.initState();
    payoutCtrl = TextEditingController(text: widget.address.value);
    _sub = miner.updates.listen((s) {
      if (mounted) setState(() => status = s);
    });
  }

  @override
  void didUpdateWidget(MineScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address.value != widget.address.value &&
        payoutCtrl.text.trim() == oldWidget.address.value) {
      payoutCtrl.text = widget.address.value;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    payoutCtrl.dispose();
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
    if (!widget.allowMining) return;
    await miner.start(built);
  }

  @override
  Widget build(BuildContext context) {
    final built = cmd;
    final line = built?.command ?? '';
    final locked = status.running;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
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
              'gnfp-mine $gnfpMineVersion · pick threads, payout gnfp1, and a live pool. TLS on :1474.',
              style: TextStyle(color: GnfpTheme.neonCyan),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('gnfp-mine-pool'),
              value: pool.id,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Pool',
                helperText: pool.hostPort,
              ),
              selectedItemBuilder: (context) => [
                for (final p in gnfpMinePools)
                  Text(p.label, overflow: TextOverflow.ellipsis),
              ],
              items: [
                for (final p in gnfpMinePools)
                  DropdownMenuItem(
                    value: p.id,
                    child: Text(p.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: locked
                  ? null
                  : (id) {
                      if (id == null) return;
                      setState(() {
                        pool = gnfpMinePools.firstWhere((p) => p.id == id);
                      });
                    },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('gnfp-mine-payout'),
              controller: payoutCtrl,
              enabled: !locked,
              style: const TextStyle(color: GnfpTheme.cream, fontSize: 13),
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Payout gnfp1',
              ),
              onChanged: (_) => setState(() {}),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('gnfp-mine-use-this-wallet'),
                onPressed: locked
                    ? null
                    : () => setState(() => payoutCtrl.text = widget.address.value),
                child: const Text('Use this wallet'),
              ),
            ),
            DropdownButtonFormField<int>(
              key: const Key('gnfp-mine-threads'),
              value: threadChoices.contains(threads) ? threads : threadChoices.last,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Threads',
                helperText: 'max ${maxThreads} (device cores minus 1)',
              ),
              items: [
                for (final n in threadChoices)
                  DropdownMenuItem(value: n, child: Text('$n')),
              ],
              onChanged: locked
                  ? null
                  : (n) {
                      if (n == null) return;
                      setState(() => threads = n > maxThreads ? maxThreads : n);
                    },
            ),
            const SizedBox(height: 12),
            SelectableText(
              line,
              key: const Key('gnfp-miner-cmd'),
              style: const TextStyle(color: GnfpTheme.neonLime, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
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
                FilledButton(
                  key: const Key('gnfp-mine-start'),
                  onPressed: built == null || (!widget.allowMining && !status.running)
                      ? null
                      : _toggle,
                  child: Text(status.running ? 'STOP' : 'MINE GNFP'),
                ),
              ],
            ),
            if (!widget.allowMining) ...[
              const SizedBox(height: 12),
              const Text(
                'Install GNFP Wallet in Applications before mining. '
                'A Downloads / disk-image copy can vanish under the miner.',
                key: Key('gnfp-mine-blocked'),
                style: TextStyle(color: GnfpTheme.neonYellow),
              ),
            ],
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
      ),
    );
  }
}
