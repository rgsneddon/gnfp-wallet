import 'package:flutter/material.dart';

import '../gnfp_analysis.dart';
import '../gnfp_theme.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final q = TextEditingController();
  final scs = TextEditingController();
  String result = '';

  @override
  void dispose() {
    q.dispose();
    scs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Analysis', style: TextStyle(fontSize: 20, color: GnfpTheme.cream)),
        const SizedBox(height: 12),
        TextField(
          key: const Key('gnfp-percent-question'),
          controller: q,
          decoration: const InputDecoration(labelText: 'Percent chance question'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('gnfp-percent-calc'),
          onPressed: () {
            final r = calculatePercentChance(q.text);
            setState(() => result = 'Percent chance ${r.percent}%');
          },
          child: const Text('Calculate percent chance'),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('gnfp-scs-scenario'),
          controller: scs,
          decoration: const InputDecoration(labelText: 'Social cohesion scenario'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('gnfp-scs-calc'),
          onPressed: () {
            final r = calculateSocialCohesion(scs.text);
            setState(() => result = 'SCS ${r.score}');
          },
          child: const Text('Calculate social cohesion score'),
        ),
        const SizedBox(height: 16),
        Text(result, key: const Key('gnfp-analysis-result')),
      ],
    );
  }
}
