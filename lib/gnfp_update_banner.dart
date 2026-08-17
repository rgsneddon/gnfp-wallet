import 'package:flutter/material.dart';

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
      color: GnfpTheme.black,
      child: Container(
        key: const Key('gnfp-update-banner'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A0A),
          border: Border(bottom: BorderSide(color: GnfpTheme.neonCyan)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A newer wallet is available (v${info.publishedVersion}). Download for this platform:',
              style: const TextStyle(
                color: GnfpTheme.cream,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            SelectableText(
              info.updateUrl,
              key: const Key('gnfp-update-url'),
              style: const TextStyle(
                color: GnfpTheme.neonCyan,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
