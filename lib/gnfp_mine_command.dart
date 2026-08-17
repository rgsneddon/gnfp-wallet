/// gnfp-mine 1.0.8 command for this wallet. Live book is TLS — no --notls.
library;

import 'dart:io';

import 'gnfp_ledger.dart';

const gnfpMineVersion = '1.0.8';
const gnfpMineClient = 'gnfp-mine';
const gnfpMineDefaultPool = gnfpStratum;
const gnfpMineDefaultThreads = 1;

/// Leave one core free: max selectable threads is device CPUs minus 1.
int gnfpMineMaxThreads({int? processors}) {
  final n = processors ?? Platform.numberOfProcessors;
  if (n <= 1) return 1;
  return n - 1;
}

List<int> gnfpMineThreadChoicesFor({int? processors}) {
  final max = gnfpMineMaxThreads(processors: processors);
  return [for (var i = 1; i <= max; i++) i];
}

/// Functioning gnfp-mine 1.0.8 stratum fronts. Book is Germany; SG joins DE;
/// HEL is the replica front. All TLS on :1474.
class GnfpMinePool {
  const GnfpMinePool({
    required this.id,
    required this.hostPort,
    required this.label,
    this.tls = true,
  });

  final String id;
  final String hostPort;
  final String label;
  final bool tls;
}

const gnfpMinePools = <GnfpMinePool>[
  GnfpMinePool(
    id: 'de',
    hostPort: gnfpStratum,
    label: 'Germany book',
  ),
  GnfpMinePool(
    id: 'sg',
    hostPort: 'sg.restoreprivacy.online:1474',
    label: 'Singapore join',
  ),
  GnfpMinePool(
    id: 'hel',
    hostPort: 'hel.restoreprivacy.online:1474',
    label: 'Helsinki front',
  ),
];

GnfpMinePool gnfpMinePoolByHost(String hostPort) {
  for (final p in gnfpMinePools) {
    if (p.hostPort == hostPort) return p;
  }
  return gnfpMinePools.first;
}

class WalletMineCommand {
  const WalletMineCommand({
    required this.command,
    required this.pool,
    required this.user,
    required this.threads,
    required this.tls,
  });

  final String command;
  final String pool;
  final String user;
  final int threads;
  final bool tls;
}

/// Auto-filled 1.0.8 line. Empty/invalid address is not runnable.
WalletMineCommand? buildWalletMineCommand({
  required String address,
  String pool = gnfpMineDefaultPool,
  int threads = gnfpMineDefaultThreads,
  bool tls = true,
  int? processors,
}) {
  final addr = GnfpAddress(address.trim());
  if (!addr.isValid) return null;
  final cap = gnfpMineMaxThreads(processors: processors);
  var n = threads < 1 ? 1 : threads;
  if (n > cap) n = cap;
  final user = '${addr.value}.worker';
  final flags = <String>[
    '--pool $pool',
    '--user $user',
    '--threads $n',
  ];
  if (!tls) flags.add('--notls');
  return WalletMineCommand(
    command: 'gnfp-mine ${flags.join(' ')}',
    pool: pool,
    user: user,
    threads: n,
    tls: tls,
  );
}
