/// Evolve Analysis surfaces: percent chance and social cohesion scoring.
///
/// Chronoflux-style local calc — no PERC treasury draw required.
library;

class PercentChanceResult {
  const PercentChanceResult({
    required this.question,
    required this.percent,
  });
  final String question;
  final double percent;
}

class ScsResult {
  const ScsResult({
    required this.scenario,
    required this.score,
  });
  final String scenario;
  final double score;
}

double _clamp(double n) => n < 0 ? 0 : (n > 100 ? 100 : n);

/// Percent chance of [question] from optional omega / sigma hints.
PercentChanceResult calculatePercentChance(
  String question, {
  double omega = 50,
  double sigma = 10,
}) {
  final q = question.trim();
  if (q.isEmpty) {
    return const PercentChanceResult(question: '', percent: 0);
  }
  var acc = omega;
  for (final c in q.codeUnits) {
    acc = (acc * 33 + c) % 10000 / 100;
  }
  final spread = sigma.abs() / 100;
  final pct = _clamp(acc * (1 - spread) + omega * spread);
  return PercentChanceResult(question: q, percent: double.parse(pct.toStringAsFixed(2)));
}

/// Social cohesion score 0–100 for a scenario.
ScsResult calculateSocialCohesion(
  String scenario, {
  double omega = 40,
  double sigma = 20,
}) {
  final s = scenario.trim();
  if (s.isEmpty) {
    return const ScsResult(scenario: '', score: 0);
  }
  var acc = omega + sigma;
  for (final c in s.toLowerCase().codeUnits) {
    acc = (acc + c * 3) % 1000 / 10;
  }
  return ScsResult(scenario: s, score: _clamp(double.parse(acc.toStringAsFixed(2))));
}
