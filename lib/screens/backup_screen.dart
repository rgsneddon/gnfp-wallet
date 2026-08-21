import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../gnfp_ledger.dart';
import '../gnfp_seed.dart';
import '../gnfp_theme.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({
    super.key,
    required this.address,
    required this.ledger,
    this.seed,
    this.onRestored,
    this.clipboard,
  });

  final GnfpAddress address;
  final GnfpLedger ledger;
  final String? seed;
  final FutureOr<void> Function(GnfpAddress address, String seed)? onRestored;
  final ClipboardDelegate? clipboard;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

/// Clipboard seam for widget tests.
class ClipboardDelegate {
  const ClipboardDelegate({this.read, this.write});
  final Future<String> Function()? read;
  final Future<void> Function(String text)? write;
}

class _BackupScreenState extends State<BackupScreen> {
  late final List<TextEditingController> boxes;
  String status = '';

  String get currentPhrase => backupPhraseFor(widget.address, seed: widget.seed);

  ClipboardDelegate get _clip =>
      widget.clipboard ??
      ClipboardDelegate(
        read: () async {
          final data = await Clipboard.getData('text/plain');
          return data?.text ?? '';
        },
        write: (text) => Clipboard.setData(ClipboardData(text: text)),
      );

  @override
  void initState() {
    super.initState();
    final words = gnfpPhraseWords(currentPhrase);
    boxes = List.generate(gnfpSeedWordCount, (i) {
      return TextEditingController(
        text: i < words.length ? words[i] : '',
      );
    });
  }

  @override
  void didUpdateWidget(BackupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address.value != widget.address.value ||
        oldWidget.seed != widget.seed) {
      _fill(currentPhrase);
    }
  }

  void _fill(String phrase) {
    final words = gnfpPhraseWords(phrase);
    for (var i = 0; i < boxes.length; i++) {
      boxes[i].text = i < words.length ? words[i] : '';
    }
  }

  String _typedPhrase() => boxes.map((c) => c.text.trim()).join(' ');

  Future<void> _copyAll() async {
    await _clip.write?.call(_typedPhrase());
    if (mounted) setState(() => status = 'copied');
  }

  Future<void> _pastePhrase() async {
    final raw = await _clip.read?.call() ?? '';
    if (raw.trim().isEmpty) return;
    setState(() {
      _fill(raw);
      status = 'pasted';
    });
  }

  Future<void> _restore() async {
    final phrase = _typedPhrase();
    final addr = restoreFromPhrase(
      phrase,
      widget.ledger,
      widget.address,
      widget.seed,
    );
    final sameWallet = addr.value == widget.address.value;
    final restoredSeed = sameWallet
        ? (widget.seed ?? addr.value)
        : restoreSeedHexFromPhrase(phrase);
    await widget.onRestored?.call(
      addr,
      restoredSeed.isNotEmpty ? restoredSeed : addr.value,
    );
    if (mounted) setState(() => status = 'restored ${addr.value}');
  }

  @override
  void dispose() {
    for (final c in boxes) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Backup', style: TextStyle(fontSize: 20, color: GnfpTheme.cream)),
        const Text(
          'Twelve English recovery words. Never a PERC seed.',
          style: TextStyle(color: GnfpTheme.neonCyan, fontSize: 12),
        ),
        const SizedBox(height: 8),
        SelectableText(
          currentPhrase,
          key: const Key('gnfp-backup-phrase'),
          style: const TextStyle(color: GnfpTheme.cream, fontSize: 12),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          key: const Key('gnfp-seed-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: gnfpSeedWordCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.6,
          ),
          itemBuilder: (context, i) {
            return TextField(
              key: Key('gnfp-seed-box-$i'),
              controller: boxes[i],
              style: const TextStyle(color: GnfpTheme.cream, fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                labelText: '${i + 1}',
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton(
              key: const Key('gnfp-copy-phrase'),
              onPressed: _copyAll,
              child: const Text('Copy all'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('gnfp-paste-phrase'),
              onPressed: _pastePhrase,
              child: const Text('Paste phrase'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('gnfp-restore'),
          onPressed: _restore,
          child: const Text('Restore'),
        ),
        const SizedBox(height: 12),
        Container(
          key: const Key('gnfp-wrong-phrase-warning'),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: GnfpTheme.black,
            border: Border.all(color: GnfpTheme.neonYellow, width: 1.4),
            boxShadow: const [
              BoxShadow(color: GnfpTheme.neonYellow, blurRadius: 8, spreadRadius: 0.4),
            ],
          ),
          child: const Text(
            gnfpWrongPhraseWarning,
            style: TextStyle(
              color: GnfpTheme.cream,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(status, key: const Key('gnfp-restore-status')),
      ],
    );
  }
}
