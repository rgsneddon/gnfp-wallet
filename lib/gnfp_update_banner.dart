import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'gnfp_theme.dart';
import 'gnfp_update.dart';

/// In-app advisory when a newer published wallet exists.
class GnfpUpdateBanner extends StatelessWidget {
  const GnfpUpdateBanner({super.key, required this.info});

  final GnfpUpdateInfo info;

  @override
  Widget build(BuildContext context) {
    if (!info.updateAvailable || info.updateUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    return Material(
      color: Colors.transparent,
      child: Container(
        key: const Key('gnfp-update-banner'),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: GnfpTheme.navyCard,
          borderRadius: BorderRadius.circular(GnfpTheme.radius),
          border: Border.all(color: GnfpTheme.neonCyan.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Update ready — ${info.publishedVersion} is published '
              '(you have ${info.localVersion}).',
              style: const TextStyle(
                color: GnfpTheme.cream,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              info.updateUrl,
              key: const Key('gnfp-update-url'),
              style: const TextStyle(
                color: GnfpTheme.neonCyan,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                key: const Key('gnfp-update-open'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: info.updateUrl));
                },
                child: const Text('Copy update link'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
