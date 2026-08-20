/// gnfp-mine 1.0.9 command for this wallet. Live book is TLS — no --notls.
library;

import 'dart:io';

import 'gnfp_ledger.dart';

const gnfpMineVersion = '1.0.5';
const gnfpMineClient = 'GNFPHash';
const gnfpMineAlgorithm = 'GNFPHash';
const gnfpMineDefaultPool = gnfpStratum;
const gnfpMineDefaultThreads = 1;
const gnfpMineDefaultWorker = 'worker';
const gnfpMineMinWorkerLen = 1;
const gnfpMineMaxWorkerLen = 24;
const gnfpMineTlsRequiredMsg =
    'pool is TLS. public book/fronts need TLS — drop --notls';
const gnfpMineOldMinerHint =
    'pool refused this client — use GNFPHash 1.0.4+ against gnfp-node 1.2.4+';
final gnfpWorkerRe = RegExp(r'^[A-Za-z0-9_-]{1,24}$');

/// Empty → default `worker`. 1–24 letters/digits/_/-. Null if illegal.
String? normalizeMineWorker(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) return gnfpMineDefaultWorker;
  if (!gnfpWorkerRe.hasMatch(s)) return null;
  return s;
}

/// Split `gnfp1….tag` or a bare gnfp1. [worker] wins over a tag on [raw].
({String address, String worker})? parseMinePayout(String raw, {String? worker}) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final dot = t.indexOf('.');
  final address = dot < 0 ? t : t.substring(0, dot);
  final tagged = dot < 0 ? '' : t.substring(dot + 1);
  final addr = GnfpAddress(address);
  if (!addr.isValid) return null;
  final name = normalizeMineWorker(
    worker != null && worker.trim().isNotEmpty ? worker : tagged,
  );
  if (name == null) return null;
  return (address: addr.value, worker: name);
}

/// Physical cores (cpuCores on the wire). 1 thread = 1 core.
class GnfpCpuInventory {
  const GnfpCpuInventory({
    required this.cpuCores,
    required this.cpuThreads,
    required this.smt,
  });

  final int cpuCores;
  final int cpuThreads;
  final int smt;

  Map<String, int> get wire => {
        'cpuCores': cpuCores,
        'cpuThreads': cpuThreads,
        'smt': smt,
        'maxThreads': cpuCores,
      };
}

int? gnfpReadPhysicalCores() {
  try {
    if (Platform.isMacOS) {
      final r = Process.runSync('sysctl', ['-n', 'hw.physicalcpu']);
      final n = int.tryParse((r.stdout as String).trim());
      if (n != null && n > 0) return n;
    } else if (Platform.isLinux) {
      final raw = File('/proc/cpuinfo').readAsStringSync();
      final seen = <String>{};
      var pid = '';
      for (final line in raw.split('\n')) {
        final phys = RegExp(r'^physical id\s*:\s*(.+)$', caseSensitive: false)
            .firstMatch(line);
        if (phys != null) pid = phys.group(1)!.trim();
        final core =
            RegExp(r'^core id\s*:\s*(.+)$', caseSensitive: false).firstMatch(line);
        if (core != null) seen.add('$pid:${core.group(1)!.trim()}');
      }
      if (seen.isNotEmpty) return seen.length;
    }
  } catch (_) {}
  return null;
}

GnfpCpuInventory gnfpDeviceCpuInventory({int? processors, int? physical}) {
  final logical = processors ?? Platform.numberOfProcessors;
  final logi = logical < 1 ? 1 : logical;
  final phys = physical ?? processors ?? gnfpReadPhysicalCores() ?? logi;
  final cores = phys < 1 ? 1 : phys;
  final threads = logi < cores ? cores : logi;
  final smt = (threads / cores).round().clamp(1, 64);
  return GnfpCpuInventory(cpuCores: cores, cpuThreads: threads, smt: smt);
}

/// Cap at logical SMT threads (12-thread CPU can run 10). Hard clamp is not here.
int gnfpHonorThreads(int requested, {int? processors, int? physical}) {
  final cap = gnfpDeviceCpuInventory(processors: processors, physical: physical)
      .cpuThreads;
  if (requested < 1) return 1;
  return requested > cap ? cap : requested;
}

/// Leave one logical thread free: max selectable is SMT threads minus 1.
int gnfpMineMaxThreads({int? processors, int? physical}) {
  final n = gnfpDeviceCpuInventory(processors: processors, physical: physical)
      .cpuThreads;
  if (n <= 1) return 1;
  return n - 1;
}

List<int> gnfpMineThreadChoicesFor({int? processors, int? physical}) {
  final max = gnfpMineMaxThreads(processors: processors, physical: physical);
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
    required this.worker,
    required this.cpuCores,
    required this.cpuThreads,
    required this.smt,
  });

  final String command;
  final String pool;
  final String user;
  final int threads;
  final bool tls;
  final String worker;
  final int cpuCores;
  final int cpuThreads;
  final int smt;

  Map<String, int> get cpuWire => {
        'cpuCores': cpuCores,
        'cpuThreads': cpuThreads,
        'smt': smt,
        'maxThreads': cpuCores,
      };
}

/// Auto-filled 1.0.2 line. Empty/invalid address or worker is not runnable.
WalletMineCommand? buildWalletMineCommand({
  required String address,
  String pool = gnfpMineDefaultPool,
  int threads = gnfpMineDefaultThreads,
  bool tls = true,
  int? processors,
  int? physical,
  String? worker,
}) {
  final parsed = parseMinePayout(address, worker: worker);
  if (parsed == null) return null;
  final inv = gnfpDeviceCpuInventory(processors: processors, physical: physical);
  final cap = gnfpMineMaxThreads(processors: processors, physical: physical);
  var n = threads < 1 ? 1 : threads;
  if (n > cap) n = cap;
  n = gnfpHonorThreads(n, processors: processors, physical: physical);
  final useTls = resolveUseTls(pool: pool, requestedTls: tls);
  final user = '${parsed.address}.${parsed.worker}';
  final flags = <String>[
    '--pool $pool',
    '--user $user',
    '--worker ${parsed.worker}',
    '--threads $n',
  ];
  if (!useTls) flags.add('--notls');
  return WalletMineCommand(
    command: 'gnfp-mine ${flags.join(' ')}',
    pool: pool,
    user: user,
    threads: n,
    tls: useTls,
    cpuCores: inv.cpuCores,
    cpuThreads: inv.cpuThreads,
    smt: inv.smt,
    worker: parsed.worker,
  );
}
