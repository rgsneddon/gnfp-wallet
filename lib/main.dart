import 'package:flutter/material.dart';

import 'gnfp_bridge.dart';
import 'gnfp_ledger.dart';
import 'gnfp_session.dart';
import 'gnfp_theme.dart';
import 'gnfp_build_stamp.dart';
import 'gnfp_update.dart';
import 'gnfp_update_banner.dart';
import 'screens/analysis_screen.dart';
import 'screens/backup_screen.dart';
import 'screens/explorer_screen.dart';
import 'screens/mine_screen.dart';
import 'screens/mix_screen.dart';
import 'screens/vpn_screen.dart';
import 'screens/wallet_screen.dart';

void main() {
  runApp(GnfpWalletApp(ledger: GnfpLedger()));
}

class GnfpWalletApp extends StatefulWidget {
  const GnfpWalletApp({
    super.key,
    required this.ledger,
    this.commitCount = kGnfpCommitCount,
    this.version,
    this.session,
    this.updateCheck,
    this.updatePlatform,
  });

  final GnfpLedger ledger;
  final int commitCount;
  final String? version;
  final GnfpSession? session;
  final GnfpUpdateCheck? updateCheck;
  final String? updatePlatform;

  @override
  State<GnfpWalletApp> createState() => _GnfpWalletAppState();
}

class _GnfpWalletAppState extends State<GnfpWalletApp> {
  late final GnfpSession session = widget.session ?? GnfpSession();
  late GnfpAddress address = widget.ledger.createAddress(seed: 'pending');
  late final RpMixer mixer = RpMixer(gnfp: widget.ledger);
  int index = 0;
  bool ready = false;
  GnfpUpdateInfo? updateInfo;

  String get stampedVersion => widget.version ?? kGnfpPackageVersion;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  /// Session first so a hung/failed update fetch cannot blank the window.
  Future<void> _boot() async {
    try {
      final loaded = await session.ensureAddress(widget.ledger);
      if (!mounted) return;
      setState(() {
        address = loaded;
        ready = true;
      });
      widget.ledger.syncSpendable(loaded).then((_) {
        if (mounted) setState(() {});
      }).catchError((_) {});
    } catch (_) {
      if (!mounted) return;
      setState(() => ready = true);
    }
    widget.ledger.networkTip().catchError((_) => 0);
    try {
      final checker = widget.updateCheck ?? const GnfpUpdateCheck();
      final info = await checker.check(
        localVersion: stampedVersion,
        platform: widget.updatePlatform,
      );
      if (!mounted) return;
      setState(() => updateInfo = info);
    } catch (_) {
      // Update advisory is optional; a failed feed must not kill the shell.
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      WalletScreen(
        ledger: widget.ledger,
        address: address,
        version: stampedVersion,
      ),
      ExplorerScreen(ledger: widget.ledger),
      BackupScreen(
        address: address,
        ledger: widget.ledger,
        onRestored: (a) async {
          await session.rememberAddress(widget.ledger, a);
          setState(() => address = a);
        },
      ),
      MixScreen(mixer: mixer, gnfpAddress: address),
      const AnalysisScreen(),
      MineScreen(address: address),
      const VpnScreen(),
    ];
    return MaterialApp(
      title: 'GNFP Wallet',
      theme: GnfpTheme.dark(),
      home: DecoratedBox(
        key: const Key('gnfp-shell'),
        decoration: const BoxDecoration(gradient: GnfpTheme.shellGradient),
        child: Scaffold(
          backgroundColor: GnfpTheme.black,
          body: Column(
                  children: [
                    if (updateInfo != null) GnfpUpdateBanner(info: updateInfo!),
                    Expanded(
                      child: !ready
                          ? const Center(child: CircularProgressIndicator())
                          : pages[index],
                    ),
                  ],
                ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => index = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
              NavigationDestination(icon: Icon(Icons.explore), label: 'Explorer'),
              NavigationDestination(icon: Icon(Icons.backup), label: 'Backup'),
              NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Mix'),
              NavigationDestination(icon: Icon(Icons.analytics), label: 'Analysis'),
              NavigationDestination(icon: Icon(Icons.memory), label: 'Mine'),
              NavigationDestination(icon: Icon(Icons.shield), label: 'VPN'),
            ],
          ),
        ),
      ),
    );
  }
}
