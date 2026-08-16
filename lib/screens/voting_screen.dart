import 'package:flutter/material.dart';

import '../gnfp_analysis.dart';
import '../gnfp_theme.dart';

class VotingScreen extends StatefulWidget {
  const VotingScreen({super.key});

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  final proposal = TextEditingController(text: 'Ward proposal');
  String last = '';

  @override
  void dispose() {
    proposal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Voting', style: TextStyle(fontSize: 20, color: GnfpTheme.cream)),
        TextField(
          key: const Key('gnfp-vote-proposal'),
          controller: proposal,
          decoration: const InputDecoration(labelText: 'Proposal'),
        ),
        FilledButton(
          key: const Key('gnfp-vote-cast'),
          onPressed: () {
            final scs = calculateSocialCohesion(proposal.text);
            final pct = calculatePercentChance(proposal.text);
            setState(() => last = 'vote ${proposal.text} scs=${scs.score} pct=${pct.percent}');
          },
          child: const Text('Vote with percent chance + SCS'),
        ),
        Text(last, key: const Key('gnfp-vote-status')),
      ],
    );
  }
}
