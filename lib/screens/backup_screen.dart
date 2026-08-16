import 'package:flutter/material.dart';

import '../gnfp_ledger.dart';
import '../gnfp_theme.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({
    super.key,
    required this.address,
    required this.ledger,
    this.onRestored,
  });

  final GnfpAddress address;
  final GnfpLedger ledger;
  final ValueChanged<GnfpAddress>? onRestored;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final phraseCtrl = TextEditingController();
  String status = '';

  @override
  void dispose() {
    phraseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phrase = backupPhraseFor(widget.address);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Backup', style: TextStyle(fontSize: 20, color: GnfpTheme.cream)),
        const Text('Write this GNFP recovery phrase down. Never a PERC seed.'),
        SelectableText(phrase, key: const Key('gnfp-backup-phrase')),
        const SizedBox(height: 16),
        TextField(
          key: const Key('gnfp-restore-phrase'),
          controller: phraseCtrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Restore phrase'),
        ),
        FilledButton(
          key: const Key('gnfp-restore'),
          onPressed: () {
            try {
              final addr = restoreFromPhrase(phraseCtrl.text, widget.ledger);
              widget.onRestored?.call(addr);
              setState(() => status = 'restored ${addr.value}');
            } catch (e) {
              setState(() => status = e.toString());
            }
          },
          child: const Text('Restore'),
        ),
        Text(status, key: const Key('gnfp-restore-status')),
      ],
    );
  }
}
