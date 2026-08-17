import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gnfp_wallet/gnfp_cpu_hash.dart';
import 'package:gnfp_wallet/gnfp_in_wallet_miner.dart';
import 'package:gnfp_wallet/gnfp_ledger.dart';
import 'package:gnfp_wallet/gnfp_mine_command.dart';

void main() {
  test('wallet mine command is gnfp-mine 1.0.9 TLS for this gnfp1', () {
    const addr = 'gnfp18ff7e8b2f0ef3e96f598231638aafd5a5abc490c';
    final cmd = buildWalletMineCommand(address: addr, threads: 2)!;
    expect(cmd.command, startsWith('gnfp-mine '));
    expect(cmd.command, contains('de.restoreprivacy.online:1474'));
    expect(cmd.command, contains('--user $addr.worker'));
    expect(cmd.command, contains('--threads 2'));
    expect(cmd.command.contains('--notls'), isFalse);
    expect(cmd.tls, isTrue);
    expect(cmd.user, '$addr.worker');
    expect(gnfpMineVersion, '1.0.9');
    expect(buildWalletMineCommand(address: 'not-an-address'), isNull);
  });

  test('stale tls:false does not pin the public book to plaintext', () {
    expect(isPublicGnfpPool('de.restoreprivacy.online:1474'), isTrue);
    expect(isPublicGnfpPool('sg.restoreprivacy.online'), isTrue);
    expect(isPublicGnfpPool('hel.restoreprivacy.online:1474'), isTrue);
    expect(isPublicGnfpPool('127.0.0.1:1474'), isFalse);
    expect(looksLikeTlsRecord([0x15, 0x03, 0x03]), isTrue);
    expect(looksLikeTlsRecord(utf8.encode('{"method":"job"}')), isFalse);
    expect(
      resolveUseTls(pool: 'de.restoreprivacy.online:1474', requestedTls: false),
      isTrue,
    );
    expect(resolveUseTls(pool: '127.0.0.1:1474', requestedTls: false), isFalse);
    final leftover = buildWalletMineCommand(
      address: 'gnfp18ff7e8b2f0ef3e96f598231638aafd5a5abc490c',
      pool: 'de.restoreprivacy.online:1474',
      tls: false,
    )!;
    expect(leftover.tls, isTrue);
    expect(leftover.command.contains('--notls'), isFalse);
    final local = buildWalletMineCommand(
      address: 'gnfp18ff7e8b2f0ef3e96f598231638aafd5a5abc490c',
      pool: '127.0.0.1:1474',
      tls: false,
    )!;
    expect(local.tls, isFalse);
    expect(local.command, contains('--notls'));
  });

  test('mine command can target another gnfp1, thread count, and a live pool', () {
    const other = 'gnfp1c91376d3ad811073a70b416539a962c9090bc67e';
    final hel = gnfpMinePoolByHost('hel.restoreprivacy.online:1474');
    expect(gnfpMinePools.map((p) => p.hostPort), contains(gnfpStratum));
    expect(gnfpMinePools.map((p) => p.hostPort), contains('sg.restoreprivacy.online:1474'));
    expect(gnfpMinePools.map((p) => p.hostPort), contains(hel.hostPort));
    final cmd = buildWalletMineCommand(
      address: other,
      pool: hel.hostPort,
      threads: 8,
      tls: hel.tls,
      processors: 9,
    )!;
    expect(cmd.user, '$other.worker');
    expect(cmd.threads, 8);
    expect(cmd.pool, 'hel.restoreprivacy.online:1474');
    expect(cmd.command, contains('--pool hel.restoreprivacy.online:1474'));
    expect(cmd.command, contains('--user $other.worker'));
    expect(cmd.command, contains('--threads 8'));
    expect(cmd.tls, isTrue);
  });

  test('thread choices stop at device processors minus 1', () {
    expect(gnfpMineMaxThreads(processors: 8), 7);
    expect(gnfpMineMaxThreads(processors: 2), 1);
    expect(gnfpMineMaxThreads(processors: 1), 1);
    expect(gnfpMineThreadChoicesFor(processors: 4), [1, 2, 3]);
    expect(gnfpMineThreadChoicesFor(processors: 4), isNot(contains(4)));
    final capped = buildWalletMineCommand(
      address: 'gnfp18ff7e8b2f0ef3e96f598231638aafd5a5abc490c',
      threads: 16,
      processors: 4,
    )!;
    expect(capped.threads, 3);
    expect(capped.command, contains('--threads 3'));
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
