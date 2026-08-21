/// Launchable CLI wallet: `dart run bin/gnfp_cli.dart -h`
import 'dart:io';

import 'package:gnfp_wallet/gnfp_cli.dart';

Future<void> main(List<String> args) async {
  exitCode = await runGnfpCli(args);
}
