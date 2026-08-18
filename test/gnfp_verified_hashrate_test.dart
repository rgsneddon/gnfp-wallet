import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gnfp_wallet/gnfp_cpu_hash.dart';
import 'package:gnfp_wallet/gnfp_in_wallet_miner.dart';
import 'package:gnfp_wallet/gnfp_mine_command.dart';

void main() {
  test('verifiedWorkRate matches pool accepted × 2^bits / elapsed', () {
    expect(jobDifficultyBits(0), 1);
    expect(jobDifficultyBits(null), 1);
    expect(jobDifficultyBits(2), 2);
    expect(verifiedWorkRate(accepted: 0, bits: 1, elapsedSec: 1), 0);
    expect(verifiedWorkRate(accepted: 1, bits: 1, elapsedSec: 0), 0);
    expect(verifiedWorkRate(accepted: 4, bits: 2, elapsedSec: 2), 8);
    expect(verifiedWorkRate(accepted: 1, bits: 1, elapsedSec: 2), 1);
    expect(
      verifiedWorkRate(accepted: 3, bits: 2, elapsedSec: 1.5),
      8,
    );
  });

  test('in-wallet H/s equals pool publishedHashrate on same accepts/bits/elapsed',
      () async {
    const addr = 'gnfp18ff7e8b2f0ef3e96f598231638aafd5a5abc490c';
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final t0 = DateTime.utc(2026, 8, 18, 12);
    var now = t0;
    Socket? poolSock;
    server.listen((sock) {
      poolSock = sock;
      sock.listen((data) {
        for (final line in utf8.decode(data).split('\n')) {
          if (line.trim().isEmpty) continue;
          final msg = jsonDecode(line);
          if (msg is! Map) continue;
          if (msg['method'] == 'login') {
            sock.add(utf8.encode(
              '${jsonEncode({
                "code": 0,
                "description": "Login Successful",
                "method": "result",
                "id": 1,
                "jsonrpc": "2.0",
              })}\n',
            ));
            sock.add(utf8.encode(
              '${jsonEncode({
                "jsonrpc": "2.0",
                "method": "job",
                "jobId": "j-rate",
                "id": "j-rate",
                "height": 12,
                "difficulty": 2,
                "input": "verified-rate",
              })}\n',
            ));
          }
        }
      }, onError: (_) {}, onDone: () {});
    }, onError: (Object e, StackTrace st) {});

    final cmd = buildWalletMineCommand(
      address: addr,
      pool: '127.0.0.1:${server.port}',
      tls: false,
    )!;
    final miner = InWalletMiner(clock: () => now);
    await miner.start(cmd);
    final readyUntil = DateTime.now().add(const Duration(seconds: 2));
    while (DateTime.now().isBefore(readyUntil) && miner.status.height != 12) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(miner.status.height, 12);
    expect(miner.status.accepted, 0, reason: 'login code=0 is not a share');
    expect(miner.status.hashrate, 0);

    now = t0.add(const Duration(seconds: 5));
    expect(miner.status.hashrate, 0, reason: 'elapsed starts at first accept');

    poolSock!.add(utf8.encode(
      '${jsonEncode({"code": 1, "description": "accepted", "method": "result"})}\n',
    ));
    final firstAcceptUntil = DateTime.now().add(const Duration(seconds: 2));
    while (DateTime.now().isBefore(firstAcceptUntil) &&
        miner.status.accepted < 1) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(miner.status.accepted, 1);

    now = t0.add(const Duration(seconds: 7));
    expect(
      miner.status.hashrate,
      verifiedWorkRate(accepted: 1, bits: 2, elapsedSec: 2),
      reason: 'elapsed is firstHashAt (t0+5) → now (t0+7), not start()',
    );
    expect(miner.status.hashrate, 2);

    poolSock!.add(utf8.encode(
      '${jsonEncode({"code": 1, "description": "accepted", "method": "result"})}\n',
    ));
    final secondAcceptUntil = DateTime.now().add(const Duration(seconds: 2));
    while (DateTime.now().isBefore(secondAcceptUntil) &&
        miner.status.accepted < 2) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(miner.status.accepted, 2);
    now = t0.add(const Duration(seconds: 9));
    expect(
      miner.status.hashrate,
      verifiedWorkRate(accepted: 2, bits: 2, elapsedSec: 4),
    );
    expect(miner.status.hashrate, 2);

    await miner.stop();
    await server.close();
  });
}
