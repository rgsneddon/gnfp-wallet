import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'gnfp_bridge.dart';
import 'gnfp_in_wallet_miner.dart';
import 'gnfp_ledger.dart';
import 'gnfp_macos_install.dart';
import 'gnfp_mining_dot.dart';
import 'gnfp_session.dart';
import 'gnfp_theme.dart';
import 'gnfp_build_stamp.dart';
import 'gnfp_update.dart';
import 'gnfp_update_banner.dart';
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
    this.miner,
    this.processors,
    this.launchExecutable,
  });

  final GnfpLedger ledger;
  final int commitCount;
  final String? version;
  final GnfpSession? session;
  final GnfpUpdateCheck? updateCheck;
  final String? updatePlatform;
  final InWalletMiner? miner;
  final int? processors;
  final String? launchExecutable;

  @override
  State<GnfpWalletApp> createState() => _GnfpWalletAppState();
}

class _GnfpWalletAppState extends State<GnfpWalletApp> {
  late final GnfpSession session = widget.session ?? GnfpSession();
  late GnfpAddress address = widget.ledger.createAddress(seed: 'pending');
  late final RpMixer mixer = RpMixer(gnfp: widget.ledger);
  late final InWalletMiner miner = widget.miner ?? InWalletMiner();
  StreamSubscription<InWalletMinerStatus>? _mineSub;
  int index = 0;
  bool ready = false;
  bool mining = false;
  GnfpUpdateInfo? updateInfo;

  String get stampedVersion => widget.version ?? kGnfpPackageVersion;

  String get _launchPath {
    if (widget.launchExecutable != null) return widget.launchExecutable!;
    try {
      return Platform.resolvedExecutable;
    } catch (_) {
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    mining = miner.status.running;
    _mineSub = miner.updates.listen((s) {
      if (!mounted) return;
      setState(() => mining = s.running);
    });
    _boot();
  }

  @override
  void dispose() {
    _mineSub?.cancel();
    if (widget.miner == null) miner.stop();
    super.dispose();
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
      widget.ledger.syncOwnerHistory(loaded).then((_) {
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
      ExplorerScreen(ledger: widget.ledger, address: address),
      BackupScreen(
        address: address,
        ledger: widget.ledger,
        onRestored: (a) async {
          await session.rememberAddress(widget.ledger, a);
          setState(() => address = a);
        },
      ),
      MixScreen(mixer: mixer, gnfpAddress: address),
      MineScreen(
        address: address,
        miner: miner,
        processors: widget.processors,
        allowMining: !shouldBlockMiningOnLaunchPath(_launchPath),
      ),
      const VpnScreen(),
    ];
    return MaterialApp(
      title: 'GNFP Wallet',
      theme: GnfpTheme.dark(),
      home: MacosApplicationsHint(
        launchExecutable: widget.launchExecutable,
        child: DecoratedBox(
        key: const Key('gnfp-shell'),
        decoration: const BoxDecoration(gradient: GnfpTheme.shellGradient),
        child: Scaffold(
          backgroundColor: GnfpTheme.black,
          body: Column(
                  children: [
                    if (updateInfo != null) GnfpUpdateBanner(info: updateInfo!),
                    Expanded(
                      child: Stack(
                        children: [
                          !ready
                              ? const Center(child: CircularProgressIndicator())
                              : pages[index],
                          if (mining)
                            const Positioned(
                              top: 10,
                              right: 10,
                              child: IgnorePointer(child: GnfpMiningDot()),
                            ),
                        ],
                      ),
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
              NavigationDestination(icon: Icon(Icons.memory), label: 'Mine'),
              NavigationDestination(icon: Icon(Icons.shield), label: 'VPN'),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
