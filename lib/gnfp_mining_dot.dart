/// Small flashing lime dot shown on every wallet page while the in-wallet
/// miner is running. Lives in shell chrome so leaving Mine does not hide it.
library;

import 'package:flutter/material.dart';

import 'gnfp_theme.dart';

const miningDotKey = Key('gnfp-mining-dot');

class GnfpMiningDot extends StatefulWidget {
  const GnfpMiningDot({super.key});

  @override
  State<GnfpMiningDot> createState() => _GnfpMiningDotState();
}

class _GnfpMiningDotState extends State<GnfpMiningDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.22, end: 1).animate(_pulse),
      child: Container(
        key: miningDotKey,
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: GnfpTheme.neonLime,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
