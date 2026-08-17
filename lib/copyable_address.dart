import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// GNFP address that can be selected and copied in one tap.
class CopyableAddress extends StatelessWidget {
  const CopyableAddress({
    super.key,
    required this.address,
    this.label = 'Address',
    this.onCopied,
  });

  final String address;
  final String label;
  final VoidCallback? onCopied;

  static Future<void> copy(String value) =>
      Clipboard.setData(ClipboardData(text: value));

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SelectableText(
            '$label $address',
            key: const Key('gnfp-address-text'),
            style: const TextStyle(
              color: Color(0xFF00E5FF),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          key: const Key('gnfp-address-copy'),
          tooltip: 'Copy address',
          icon: const Icon(Icons.copy),
          onPressed: () async {
            await copy(address);
            onCopied?.call();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Address copied')),
            );
          },
        ),
      ],
    );
  }
}
