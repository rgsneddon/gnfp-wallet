import 'package:flutter/material.dart';

import '../gnfp_theme.dart';

/// Restore Privacy VPN placeholder. Static until the VPN client is wired in.
class VpnScreen extends StatelessWidget {
  const VpnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Restore Privacy VPN',
            key: Key('gnfp-vpn-title'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: GnfpTheme.cream,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'coming soon',
            key: Key('gnfp-vpn-coming-soon'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: GnfpTheme.neonCyan,
            ),
          ),
        ],
      ),
    );
  }
}
