/// gnfp-mine 1.0.8 command for this wallet. Live book is TLS — no --notls.
library;

import 'gnfp_ledger.dart';

const gnfpMineVersion = '1.0.8';
const gnfpMineClient = 'gnfp-mine';
const gnfpMineDefaultPool = gnfpStratum;
const gnfpMineDefaultThreads = 1;

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
}) {
  final addr = GnfpAddress(address.trim());
  if (!addr.isValid) return null;
  final n = threads < 1 ? 1 : (threads > 256 ? 256 : threads);
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
