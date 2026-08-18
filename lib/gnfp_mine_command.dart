/// gnfp-mine 1.0.9 command for this wallet. Live book is TLS — no --notls.
library;

import 'dart:io';

import 'gnfp_ledger.dart';

const gnfpMineVersion = '1.0.1';
const gnfpMineClient = 'GNFPHash';
const gnfpMineAlgorithm = 'GNFPHash';
const gnfpMineDefaultPool = gnfpStratum;
const gnfpMineDefaultThreads = 1;
const gnfpMineTlsRequiredMsg =
    'pool is TLS. public book/fronts need TLS — drop --notls';

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

/// Official Germany and Singapore pools speak TLS. --notls is local only.
bool isPublicGnfpPool(String hostPort) {
  final host = hostPort.trim().toLowerCase().split(':').first.replaceAll(RegExp(r'\.$'), '');
  return host == 'restoreprivacy.online' || host.endsWith('.restoreprivacy.online');
}

/// TLS unless an explicit local `--notls`. A leftover 1.0.7 `tls: false`
/// must not pin public book/front connections to plaintext.
bool resolveUseTls({required String pool, required bool requestedTls}) {
  if (isPublicGnfpPool(pool)) return true;
  return requestedTls;
}

/// First byte of a TLS record (handshake / alert / appdata).
bool looksLikeTlsRecord(List<int> chunk) {
  if (chunk.isEmpty) return false;
  final c = chunk.first;
  return c == 0x14 || c == 0x15 || c == 0x16 || c == 0x17;
}

/// Official gnfp-mine 1.0.9 pools. Germany and Singapore only; Custom is typed.
/// All official hosts are TLS on :1474. No Helsinki.
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
    label: 'Germany · de.restoreprivacy.online:1474',
  ),
  GnfpMinePool(
    id: 'sg',
    hostPort: 'sg.restoreprivacy.online:1474',
    label: 'Singapore · sg.restoreprivacy.online:1474',
  ),
];

const gnfpMineCustomPoolId = 'custom';

GnfpMinePool gnfpMinePoolByHost(String hostPort) {
  final host = normalizeMinePoolHost(hostPort);
  for (final p in gnfpMinePools) {
    if (p.hostPort == host) return p;
  }
  if (host.isEmpty) return gnfpMinePools.first;
  return GnfpMinePool(
    id: gnfpMineCustomPoolId,
    hostPort: host,
    label: 'Custom pool',
    tls: defaultTlsForPool(host),
  );
}

/// Accept host, host:port, or stratum URL. Empty stays empty.
String normalizeMinePoolHost(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return '';
  s = s.replaceFirst(RegExp(r'^(stratum\+)?(ssl|tcp):\/\/', caseSensitive: false), '');
  s = s.replaceFirst(RegExp(r'^https?:\/\/', caseSensitive: false), '');
  if (s.endsWith('/')) s = s.substring(0, s.length - 1);
  if (!s.contains(':')) s = '$s:1474';
  return s;
}

/// Public restoreprivacy hosts and other remote pools use TLS.
/// Loopback is plaintext unless the caller asked for TLS.
bool defaultTlsForPool(String pool) {
  if (isPublicGnfpPool(pool)) return true;
  final host = pool.trim().toLowerCase().split(':').first;
  if (host == '127.0.0.1' || host == 'localhost' || host == '::1') return false;
  return true;
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

/// Auto-filled 1.0.9 line. Empty/invalid address is not runnable.
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
  final useTls = resolveUseTls(pool: pool, requestedTls: tls);
  final user = '${addr.value}.worker';
  final flags = <String>[
    '--pool $pool',
    '--user $user',
    '--threads $n',
  ];
  if (!useTls) flags.add('--notls');
  return WalletMineCommand(
    command: 'gnfp-mine ${flags.join(' ')}',
    pool: pool,
    user: user,
    threads: n,
    tls: useTls,
  );
}
