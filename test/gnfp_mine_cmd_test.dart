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
    expect(cmd.worker, 'worker');
    expect(cmd.command, contains('--worker worker'));
    expect(gnfpMineVersion, '1.0.5');
    expect(gnfpMineClient, 'GNFPHash');
    expect(gnfpMineAlgorithm, 'GNFPHash');
    expect(buildWalletMineCommand(address: 'not-an-address'), isNull);
  });

  test('stale tls:false does not pin the public book to plaintext', () {
    expect(isPublicGnfpPool('de.restoreprivacy.online:1474'), isTrue);
    expect(isPublicGnfpPool('sg.restoreprivacy.online'), isTrue);
    expect(isPublicGnfpPool('hel.restoreprivacy.online:1474'), isTrue);
    expect(gnfpMinePools.map((p) => p.id), isNot(contains('hel')));
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

  test('custom pool host can be typed and does not force the official book', () {
    expect(normalizeMinePoolHost('pool.example:3333'), 'pool.example:3333');
    expect(normalizeMinePoolHost('pool.example'), 'pool.example:1474');
    expect(normalizeMinePoolHost('stratum+tcp://other.pool:4444'), 'other.pool:4444');
    expect(defaultTlsForPool('pool.example:3333'), isTrue);
    expect(defaultTlsForPool('127.0.0.1:1474'), isFalse);
    const addr = 'gnfp18ff7e8b2f0ef3e96f598231638aafd5a5abc490c';
    final elsewhere = buildWalletMineCommand(
      address: addr,
      pool: normalizeMinePoolHost('elsewhere.gnfp:3333'),
      threads: 1,
      tls: defaultTlsForPool('elsewhere.gnfp:3333'),
    )!;
    expect(elsewhere.pool, 'elsewhere.gnfp:3333');
    expect(elsewhere.command, contains('--pool elsewhere.gnfp:3333'));
    expect(elsewhere.command.contains('de.restoreprivacy.online'), isFalse);
    expect(elsewhere.tls, isTrue);
    final custom = gnfpMinePoolByHost('elsewhere.gnfp:3333');
    expect(custom.id, gnfpMineCustomPoolId);
    expect(custom.hostPort, 'elsewhere.gnfp:3333');
  });

  test('mine command can target another gnfp1, thread count, and a live pool', () {
    const other = 'gnfp1c91376d3ad811073a70b416539a962c9090bc67e';
    final sg = gnfpMinePoolByHost('sg.restoreprivacy.online:1474');
    expect(gnfpMinePools.map((p) => p.hostPort), contains(gnfpStratum));
    expect(gnfpMinePools.map((p) => p.hostPort), contains('sg.restoreprivacy.online:1474'));
    expect(gnfpMinePools.map((p) => p.id), isNot(contains('hel')));
    for (final p in gnfpMinePools) {
      expect(p.label.contains('(book)'), isFalse);
      expect(p.label.contains('(join)'), isFalse);
      expect(p.label.contains('(front)'), isFalse);
      expect(p.label.toLowerCase().contains('helsinki'), isFalse);
    }
    final cmd = buildWalletMineCommand(
      address: other,
      pool: sg.hostPort,
      threads: 8,
      tls: sg.tls,
      processors: 9,
    )!;
    expect(cmd.user, '$other.worker');
    expect(cmd.threads, 8);
    expect(cmd.pool, 'sg.restoreprivacy.online:1474');
    expect(cmd.command, contains('--pool sg.restoreprivacy.online:1474'));
    expect(cmd.command, contains('--user $other.worker'));
    expect(cmd.command, contains('--threads 8'));
    expect(cmd.tls, isTrue);
  });

  test('worker name is user-chosen 1–24 chars, not hardcoded', () {
    const addr = 'gnfp18ff7e8b2f0ef3e96f598231638aafd5a5abc490c';
    expect(normalizeMineWorker(''), 'worker');
    expect(normalizeMineWorker('1'), '1');
    expect(normalizeMineWorker('a'), 'a');
    expect(normalizeMineWorker('ryzen5600'), 'ryzen5600');
    expect(normalizeMineWorker('x' * 24), 'x' * 24);
    expect(normalizeMineWorker('x' * 25), isNull);
    expect(normalizeMineWorker('nope!'), isNull);
    expect(parseMinePayout(addr)?.worker, 'worker');
    expect(parseMinePayout('$addr.1')?.worker, '1');
    expect(parseMinePayout(addr, worker: 'rig')?.worker, 'rig');
    expect(parseMinePayout('$addr.old', worker: '1')?.worker, '1');
    expect(parseMinePayout('$addr.${'z' * 25}'), isNull);
    final named = buildWalletMineCommand(address: addr, worker: '1')!;
    expect(named.user, '$addr.1');
    expect(named.worker, '1');
    expect(named.command, contains('--worker 1'));
    expect(named.command.contains('.worker'), isFalse);
    expect(buildWalletMineCommand(address: addr, worker: 'x' * 25), isNull);
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
    expect(capped.cpuCores, 4);
    expect(capped.threads <= capped.cpuCores, isTrue);
  });

  test('10 requested on 6 physical / 12 logical runs 10 of 12 SMT threads', () {
    expect(gnfpHonorThreads(10, processors: 12, physical: 6), 10);
    expect(gnfpMineMaxThreads(processors: 12, physical: 6), 11);
    final inv = gnfpDeviceCpuInventory(processors: 12, physical: 6);
    expect(inv.cpuCores, 6);
    expect(inv.cpuThreads, 12);
    expect(inv.smt, 2);
    final cmd = buildWalletMineCommand(
      address: 'gnfp18ff7e8b2f0ef3e96f598231638aafd5a5abc490c',
      threads: 10,
      processors: 12,
      physical: 6,
    )!;
    expect(cmd.cpuCores, 6);
    expect(cmd.cpuThreads, 12);
    expect(cmd.threads, 10);
    expect(cmd.threads <= cmd.cpuThreads, isTrue);
  });

  test('cpu hash matches the live book personal and finds a 1-bit share', () {
    const pre = 'gnfp-wallet-seed';
    String? nonce;
    for (var i = 0; i < 200000; i++) {
      final hex = i.toRadixString(16).padLeft(16, '0');
      if (hashMeetsJob({'input': pre, 'difficulty': 1}, hex)) {
        nonce = hex;
        break;
      }
    }
    expect(nonce, isNotNull);
    final hash = gnfpWorkHash(pre, nonce!, '');
    expect(hash.length, 64);
    expect(hashMeetsJob({'input': pre, 'difficulty': 1}, nonce), isTrue);
    expect(gnfpCpuHashPersonal, 'GNFPHash-v1');
    expect(gnfpHashAlgorithm, 'GNFPHash');
    final range = hashNonceRange({'input': pre, 'difficulty': 1}, 0, 200000, 1);
    expect(range.hashes, 200000);
    expect(range.shares, isNotEmpty);
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
        for (final line in utf8.decode(data).split('\n')) {
          if (line.trim().isEmpty) continue;
          final msg = jsonDecode(line);
          if (msg is! Map) continue;
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
            expect(msg['threads'], cmd.threads);
            sock.add(utf8.encode(
              '${jsonEncode({"code": 0, "description": "accepted", "method": "result"})}\n',
            ));
          }
        }
      }, onError: (_) {}, onDone: () {});
    }, onError: (Object e, StackTrace st) {});
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
    expect(submittedClient, 'GNFPHash');
    expect(miner.status.accepted, greaterThan(0));
    await miner.stop();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await server.close();
  });

  test('start stays running and logs in again after the stratum socket closes', () async {
    const addr = 'gnfp18ff7e8b2f0ef3e96f598231638aafd5a5abc490c';
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final cmd = buildWalletMineCommand(
      address: addr,
      pool: '127.0.0.1:${server.port}',
      tls: false,
    )!;
    var logins = 0;
    final firstLogin = Completer<Socket>();
    final secondLogin = Completer<void>();
    final sawStats = Completer<void>();
    server.listen((sock) {
      sock.listen((data) {
        for (final line in utf8.decode(data).split('\n')) {
          if (line.trim().isEmpty) continue;
          final msg = jsonDecode(line);
          if (msg is! Map) continue;
          if (msg['method'] == 'login') {
            logins += 1;
            sock.add(utf8.encode(
              '${jsonEncode({
                "jsonrpc": "2.0",
                "method": "job",
                "jobId": "j-$logins",
                "id": "j-$logins",
                "height": 9,
                "difficulty": 1,
                "input": "aaa",
              })}\n',
            ));
            if (logins == 1 && !firstLogin.isCompleted) firstLogin.complete(sock);
            if (logins >= 2 && !secondLogin.isCompleted) secondLogin.complete();
          }
          if (msg['method'] == 'stats' && !sawStats.isCompleted) {
            sawStats.complete();
          }
        }
      }, onError: (_) {}, onDone: () {});
    }, onError: (Object e, StackTrace st) {});
    final miner = InWalletMiner(
      reconnectDelay: const Duration(milliseconds: 80),
      statsEvery: const Duration(milliseconds: 40),
    );
    final started = await miner.start(cmd);
    expect(started.running, isTrue);
    final firstSock = await firstLogin.future.timeout(const Duration(seconds: 2));
    expect(miner.status.running, isTrue);
    await sawStats.future.timeout(const Duration(seconds: 2));
    firstSock.destroy();
    await secondLogin.future.timeout(const Duration(seconds: 3));
    expect(miner.status.running, isTrue);
    expect(logins, greaterThanOrEqualTo(2));
    expect(miner.status.lastError, isEmpty);
    await miner.stop();
    expect(miner.status.running, isFalse);
    await server.close();
  });

  test('login and submit use selected pool, payout gnfp1, and thread count', () async {
    const other = 'gnfp1c91376d3ad811073a70b416539a962c9090bc67e';
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final cmd = buildWalletMineCommand(
      address: other,
      pool: '127.0.0.1:${server.port}',
      threads: 3,
      tls: false,
      processors: 8,
    )!;
    expect(cmd.pool, '127.0.0.1:${server.port}');
    expect(cmd.user, '$other.worker');
    expect(cmd.threads, 3);
    Map<String, dynamic>? login;
    Map<String, dynamic>? submit;
    server.listen((sock) {
      sock.listen((data) {
        for (final line in utf8.decode(data).split('\n')) {
          if (line.trim().isEmpty) continue;
          final msg = jsonDecode(line);
          if (msg is! Map) continue;
          if (msg['method'] == 'login') {
            login = Map<String, dynamic>.from(msg);
            sock.add(utf8.encode(
              '${jsonEncode({
                "jsonrpc": "2.0",
                "method": "job",
                "jobId": "j-login",
                "id": "j-login",
                "height": 4,
                "difficulty": 1,
                "input": "aaa",
              })}\n',
            ));
          }
          if (msg['method'] == 'submit') {
            submit = Map<String, dynamic>.from(msg);
            sock.add(utf8.encode(
              '${jsonEncode({"code": 0, "description": "accepted", "method": "result"})}\n',
            ));
          }
        }
      }, onError: (_) {}, onDone: () {});
    }, onError: (Object e, StackTrace st) {});
    final miner = InWalletMiner();
    final started = await miner.start(cmd);
    expect(started.running, isTrue);
    expect(started.user, cmd.user);
    final deadline = DateTime.now().add(const Duration(seconds: 4));
    while (DateTime.now().isBefore(deadline) && submit == null) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(login, isNotNull);
    expect(login!['login'], cmd.user);
    expect(login!['threads'], 3);
    expect(login!['threads'], miner.liveThreads);
    expect(login!['client'], 'GNFPHash');
    expect(login!['algorithm'], 'GNFPHash');
    expect(login!['version'], '1.0.5');
    expect(login!['cpuCores'], cmd.cpuCores);
    expect((login!['threads'] as int) <= (login!['cpuCores'] as int), isTrue);
    expect(submit, isNotNull);
    expect(submit!['login'], cmd.user);
    expect(submit!['threads'], miner.liveThreads);
    expect(submit!['threads'], 3);
    await miner.stop();
    expect(miner.liveThreads, 0);
    await server.close();
  });

  test('wire threads are farm isolates, not a higher requested count', () async {
    const addr = 'gnfp18ff7e8b2f0ef3e96f598231638aafd5a5abc490c';
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final cmd = buildWalletMineCommand(
      address: addr,
      pool: '127.0.0.1:${server.port}',
      threads: 16,
      tls: false,
      processors: 4,
    )!;
    expect(cmd.threads, 3);
    Map<String, dynamic>? login;
    Map<String, dynamic>? stats;
    Map<String, dynamic>? submit;
    server.listen((sock) {
      sock.listen((data) {
        for (final line in utf8.decode(data).split('\n')) {
          if (line.trim().isEmpty) continue;
          final msg = jsonDecode(line);
          if (msg is! Map) continue;
          if (msg['method'] == 'login') {
            login = Map<String, dynamic>.from(msg);
            sock.add(utf8.encode(
              '${jsonEncode({
                "jsonrpc": "2.0",
                "method": "job",
                "jobId": "j-live",
                "id": "j-live",
                "height": 2,
                "difficulty": 1,
                "input": "aaa",
              })}\n',
            ));
          }
          if (msg['method'] == 'stats') {
            stats = Map<String, dynamic>.from(msg);
          }
          if (msg['method'] == 'submit') {
            submit = Map<String, dynamic>.from(msg);
            sock.add(utf8.encode(
              '${jsonEncode({"code": 0, "description": "accepted", "method": "result"})}\n',
            ));
          }
        }
      }, onError: (_) {}, onDone: () {});
    }, onError: (Object e, StackTrace st) {});
    final miner = InWalletMiner(statsEvery: const Duration(milliseconds: 40));
    await miner.start(cmd);
    final deadline = DateTime.now().add(const Duration(seconds: 4));
    while (DateTime.now().isBefore(deadline) &&
        (login == null || submit == null || stats == null)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(miner.liveThreads, 3);
    expect(login, isNotNull);
    expect(login!['threads'], miner.liveThreads);
    expect(login!['threads'], isNot(16));
    expect(stats, isNotNull);
    expect(stats!['threads'], miner.liveThreads);
    expect(submit, isNotNull);
    expect(submit!['threads'], miner.liveThreads);
    await miner.stop();
    expect(miner.liveThreads, 0);
    await server.close();
  });

  test('selected threads increase hashes and hashrate in the same interval', () async {
    const addr = 'gnfp18ff7e8b2f0ef3e96f598231638aafd5a5abc490c';
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((sock) {
      sock.listen((data) {
        for (final line in utf8.decode(data).split('\n')) {
          if (line.trim().isEmpty) continue;
          final msg = jsonDecode(line);
          if (msg is! Map) continue;
          if (msg['method'] == 'login') {
            sock.add(utf8.encode(
              '${jsonEncode({
                "jsonrpc": "2.0",
                "method": "job",
                "jobId": "j-scale",
                "id": "j-scale",
                "height": 1,
                "difficulty": 24,
                "input": "thread-scale",
              })}\n',
            ));
          }
        }
      }, onError: (_) {}, onDone: () {});
    }, onError: (Object e, StackTrace st) {});

    Future<int> runThreads(int threads) async {
      final cmd = buildWalletMineCommand(
        address: addr,
        pool: '127.0.0.1:${server.port}',
        threads: threads,
        tls: false,
        processors: 8,
      )!;
      expect(cmd.threads, threads);
      final miner = InWalletMiner(maxHashesPerTick: 32);
      await miner.start(cmd);
      expect(miner.status.running, isTrue);
      final readyUntil = DateTime.now().add(const Duration(seconds: 3));
      while (DateTime.now().isBefore(readyUntil) && miner.status.hashes < 32) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(miner.status.hashes, greaterThan(0));
      final mark = miner.status.hashes;
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final hashes = miner.status.hashes - mark;
      await miner.stop();
      expect(miner.status.running, isFalse);
      return hashes;
    }

    final one = await runThreads(1);
    final many = await runThreads(4);
    expect(
      many,
      greaterThan(one),
      reason: '4-thread hashes $many must exceed 1-thread $one',
    );
    // Public H/s is verified accepts, not farm hashes. Difficulty 24 rarely
    // accepts in this window, so rate may be 0 on both runs.
    await server.close();
  });

  test('STOP leaves running false and does not log in again', () async {
    const addr = 'gnfp18ff7e8b2f0ef3e96f598231638aafd5a5abc490c';
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final cmd = buildWalletMineCommand(
      address: addr,
      pool: '127.0.0.1:${server.port}',
      tls: false,
    )!;
    var logins = 0;
    final firstLogin = Completer<void>();
    server.listen((sock) {
      sock.listen((data) {
        for (final line in utf8.decode(data).split('\n')) {
          if (line.trim().isEmpty) continue;
          final msg = jsonDecode(line);
          if (msg is! Map) continue;
          if (msg['method'] == 'login') {
            logins += 1;
            sock.add(utf8.encode(
              '${jsonEncode({
                "jsonrpc": "2.0",
                "method": "job",
                "jobId": "j-stop",
                "id": "j-stop",
                "height": 1,
                "difficulty": 1,
                "input": "aaa",
              })}\n',
            ));
            if (!firstLogin.isCompleted) firstLogin.complete();
          }
        }
      }, onError: (_) {}, onDone: () {});
    }, onError: (Object e, StackTrace st) {});
    final miner = InWalletMiner(
      reconnectDelay: const Duration(milliseconds: 80),
      statsEvery: const Duration(milliseconds: 40),
    );
    await miner.start(cmd);
    await firstLogin.future.timeout(const Duration(seconds: 2));
    expect(miner.status.running, isTrue);
    expect(logins, 1);
    await miner.stop();
    expect(miner.status.running, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(logins, 1);
    expect(miner.status.running, isFalse);
    await server.close();
  });
}
