import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

class RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)..badCertificateCallback = (_, __, ___) => true;
  }
}

class PoolHandle {
  PoolHandle(this.uri, this.process);
  final Uri uri;
  final Process process;
  Future<void> stop() async {
    process.kill();
    await process.exitCode;
  }
}

Future<PoolHandle> startShippedPool() async {
  final here = Directory.current;
  final root = here.path.endsWith('wallet') ? here.parent : here;
  final script = File('${root.path}${Platform.pathSeparator}scripts${Platform.pathSeparator}wallet_http.mjs');
  expect(script.existsSync(), isTrue, reason: 'shipped ${script.path}');
  final proc = await Process.start(
    'node',
    [script.path],
    workingDirectory: root.path,
  );
  final line = await proc.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .firstWhere(
        (row) => row.contains('GNFP_WALLET_HTTP='),
        orElse: () => '',
      )
      .timeout(const Duration(seconds: 8), onTimeout: () => '');
  if (line.isEmpty) {
    final err = await proc.stderr.transform(utf8.decoder).take(1).join();
    fail('shipped pool did not start: $err');
  }
  final port = int.parse(line.split('=').last.trim());
  return PoolHandle(Uri.parse('http://127.0.0.1:$port'), proc);
}
