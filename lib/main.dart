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
import 'screens/credit_screen.dart';
import 'screens/explorer_screen.dart';
import 'screens/mix_screen.dart';
import 'screens/voting_screen.dart';
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
  int index = 1;
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
      const AnalysisScreen(),
      WalletScreen(
        ledger: widget.ledger,
        address: address,
      ),
      BackupScreen(
        address: address,
        ledger: widget.ledger,
        onRestored: (a) async {
          await session.rememberAddress(widget.ledger, a);
          setState(() => address = a);
        },
      ),
      const VotingScreen(),
      CreditScreen(ledger: widget.ledger, address: address),
      ExplorerScreen(ledger: widget.ledger),
      MixScreen(mixer: mixer, gnfpAddress: address),
    ];
    return MaterialApp(
      title: 'GNFP Wallet',
      theme: GnfpTheme.dark(),
      home: DecoratedBox(
        key: const Key('gnfp-shell'),
        decoration: const BoxDecoration(gradient: GnfpTheme.shellGradient),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GNFP Wallet',
                  style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.4),
                ),
                Text(
                  'GNFP $stampedVersion',
                  style: const TextStyle(
                    fontSize: 12,
                    color: GnfpTheme.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          body: !ready
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    if (updateInfo != null) GnfpUpdateBanner(info: updateInfo!),
                    Expanded(child: pages[index]),
                  ],
                ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => index = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.analytics), label: 'Analysis'),
              NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
              NavigationDestination(icon: Icon(Icons.backup), label: 'Backup'),
              NavigationDestination(icon: Icon(Icons.how_to_vote), label: 'Voting'),
              NavigationDestination(icon: Icon(Icons.payments), label: 'Credit'),
              NavigationDestination(icon: Icon(Icons.explore), label: 'Explorer'),
              NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Mix'),
            ],
          ),
        ),
      ),
    );
  }
}
