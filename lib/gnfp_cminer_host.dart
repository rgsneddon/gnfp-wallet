/// Locate and talk to bundled gnfp-cminer 1.1.0 on desktop Mine.
library;

import 'dart:io';

import 'gnfp_mine_command.dart';

/// Desktop Mine spawns bundled gnfp-cminer. Phones keep the Dart hasher.
/// [flutterTest] defaults true under `flutter test` so existing isolate tests
/// stay on the Dart path unless a test opts in with [InWalletMiner.useBundledCminer].
bool gnfpMineUsesBundledCminer({
  bool? isIOS,
  bool? isAndroid,
  bool? isMacOS,
  bool? isWindows,
  bool? isLinux,
  bool? flutterTest,
}) {
  final ios = isIOS ?? Platform.isIOS;
  final android = isAndroid ?? Platform.isAndroid;
  if (ios || android) return false;
  final mac = isMacOS ?? Platform.isMacOS;
  final win = isWindows ?? Platform.isWindows;
  final linux = isLinux ?? Platform.isLinux;
  if (!(mac || win || linux)) return false;
  final test = flutterTest ?? (Platform.environment['FLUTTER_TEST'] == 'true');
  if (test) return false;
  return true;
}

String gnfpCminerFileName({bool? isWindows}) =>
    (isWindows ?? Platform.isWindows) ? 'gnfp-cminer.exe' : 'gnfp-cminer';

/// Argv for the bundled binary (no program name).
List<String> gnfpCminerArgs(WalletMineCommand cmd) {
  final args = <String>[
    '--pool',
    cmd.pool,
    '--user',
    cmd.user,
    '--threads',
    '${cmd.threads}',
  ];
  if (!cmd.tls) args.add('--notls');
  return args;
}

String? locateBundledCminer({
  String? resolvedExecutable,
  bool? isWindows,
  Iterable<String>? extraDirs,
}) {
  final name = gnfpCminerFileName(isWindows: isWindows);
  final dirs = <String>[];
  try {
    final exe = resolvedExecutable ?? Platform.resolvedExecutable;
    dirs.add(File(exe).parent.path);
  } catch (_) {}
  if (extraDirs != null) dirs.addAll(extraDirs);
  for (final d in dirs) {
    if (d.isEmpty) continue;
    final f = File('$d${Platform.pathSeparator}$name');
    if (f.existsSync()) return f.path;
  }
  return null;
}

class CminerStatusParse {
  const CminerStatusParse({
    this.hashrate,
    this.accepted,
    this.rejected,
    this.threads,
    this.height,
    this.bits,
    this.user,
    this.shareAccepted = false,
    this.shareRejected = false,
    this.blockFound = false,
  });

  final double? hashrate;
  final int? accepted;
  final int? rejected;
  final int? threads;
  final int? height;
  final int? bits;
  final String? user;
  final bool shareAccepted;
  final bool shareRejected;
  final bool blockFound;
}

final _rateRe = RegExp(
  r'hashrate=([0-9.]+)\s+H/s\s+worker=(\S+)\s+accepted=(\d+)\s+rejected=(\d+)\s+blocks=\d+\s+threads=(\d+)\s+height=(\d+)',
);
final _jobRe = RegExp(r'job\s+\S+\s+height=(\d+)\s+diff=(\d+)');

/// Parse one gnfp-cminer 1.1.0 stdout line.
CminerStatusParse parseCminerLine(String raw) {
  final line = raw.trim();
  if (line.isEmpty) return const CminerStatusParse();
  final rate = _rateRe.firstMatch(line);
  if (rate != null) {
    return CminerStatusParse(
      hashrate: double.tryParse(rate.group(1)!),
      user: rate.group(2),
      accepted: int.parse(rate.group(3)!),
      rejected: int.parse(rate.group(4)!),
      threads: int.parse(rate.group(5)!),
      height: int.parse(rate.group(6)!),
    );
  }
  final job = _jobRe.firstMatch(line);
  if (job != null) {
    return CminerStatusParse(
      height: int.parse(job.group(1)!),
      bits: int.parse(job.group(2)!),
    );
  }
  final low = line.toLowerCase();
  if (low.startsWith('accepted share') || low == 'block found') {
    return CminerStatusParse(
      shareAccepted: true,
      blockFound: low == 'block found',
    );
  }
  if (low.startsWith('rejected share')) {
    return const CminerStatusParse(shareRejected: true);
  }
  return const CminerStatusParse();
}
