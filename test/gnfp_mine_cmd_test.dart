import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gnfp_wallet/gnfp_cpu_hash.dart';
import 'package:gnfp_wallet/gnfp_in_wallet_miner.dart';
import 'package:gnfp_wallet/gnfp_mine_command.dart';

void main() {
  test('wallet mine command is gnfp-mine 1.0.8 TLS for this gnfp1', () {
    const addr = 'gnfp18ff7e8b2f0ef3e96f598231638aafd5a5abc490c';
    final cmd = buildWalletMineCommand(address: addr, threads: 2)!;
    expect(cmd.command, startsWith('gnfp-mine '));
    expect(cmd.command, contains('de.restoreprivacy.online:1474'));
    expect(cmd.command, contains('--user $addr.worker'));
    expect(cmd.command, contains('--threads 2'));
    expect(cmd.command.contains('--notls'), isFalse);
    expect(cmd.tls, isTrue);
    expect(cmd.user, '$addr.worker');
    expect(buildWalletMineCommand(address: 'not-an-address'), isNull);
  });

  test('cpu hash matches the live book personal and finds a 1-bit share', () {
    const pre = 'gnfp-wallet-seed';
    const nonce = '0000000000000006';
    final hash = gnfpWorkHash(pre, nonce, '');
    expect(hash.length, 64);
    expect(hashMeetsJob({'input': pre, 'difficulty': 1}, nonce), isTrue);
  });

  test('start hashing submits as this gnfp1.worker on a local stratum', () async {
    const addr = 'gnfp18ff7e8b2f0ef3e96f598231638aafd5a5abc490c';
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final cmd = buildWalletMineCommand(
      address: addr,
      pool: '127.0.0.1:${server.port}',
      tls: false,
    )!;
    String? submittedUser;
    String? submittedClient;
    final loggedIn = Completer<void>();
    server.listen((sock) {
      sock.listen((data) {
        final line = utf8.decode(data).trim();
        if (line.isEmpty) return;
        final msg = jsonDecode(line);
        if (msg is! Map) return;
        if (msg['method'] == 'login') {
          sock.add(utf8.encode(
            '${jsonEncode({
              "jsonrpc": "2.0",
              "method": "job",
              "jobId": "j-1",
              "id": "j-1",
              "height": 9,
              "difficulty": 1,
              "input": "aaa",
            })}\n',
          ));
          if (!loggedIn.isCompleted) loggedIn.complete();
        }
        if (msg['method'] == 'submit') {
          submittedUser = msg['login']?.toString();
          submittedClient = msg['client']?.toString();
          sock.add(utf8.encode(
            '${jsonEncode({"code": 0, "description": "accepted", "method": "result"})}\n',
          ));
        }
      });
    });
    final miner = InWalletMiner();
    final started = await miner.start(cmd);
    expect(started.user, cmd.user);
    expect(started.running, isTrue);
    await loggedIn.future.timeout(const Duration(seconds: 2));
    final deadline = DateTime.now().add(const Duration(seconds: 4));
    while (DateTime.now().isBefore(deadline) && submittedUser == null) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(submittedUser, cmd.user);
    expect(submittedClient, 'gnfp-mine');
    expect(miner.status.accepted, greaterThan(0));
    await miner.stop();
    await server.close();
  });
}
