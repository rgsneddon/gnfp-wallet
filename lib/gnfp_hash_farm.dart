/// One Dart isolate per selected mine thread. Main isolate owns stratum I/O.
library;

import 'dart:async';
import 'dart:isolate';

import 'gnfp_cpu_hash.dart';

/// Persistent CPU hash workers. [threads] isolates hash in parallel.
class GnfpHashFarm {
  GnfpHashFarm({
    this.batchSize = 32,
    this.onHashed,
    this.onShare,
  });

  final int batchSize;
  final void Function(int n)? onHashed;
  final void Function(String nonce, Map<String, dynamic> job)? onShare;

  final _workers = <Isolate>[];
  final _ports = <SendPort>[];
  ReceivePort? _inbox;
  StreamSubscription<dynamic>? _sub;

  int get threads => _ports.length;
  bool get isRunning => _ports.isNotEmpty;

  Future<void> start(int threads) async {
    await stop();
    final n = threads < 1 ? 1 : threads;
    _inbox = ReceivePort();
    _sub = _inbox!.listen(_onMsg);
    for (var i = 0; i < n; i++) {
      try {
        final ready = ReceivePort();
        final iso = await Isolate.spawn(
          gnfpHashWorkerMain,
          ready.sendPort,
          debugName: 'gnfp-hash-$i',
        );
        final port = await ready.first.timeout(const Duration(seconds: 5));
        ready.close();
        if (port is! SendPort) {
          iso.kill(priority: Isolate.immediate);
          continue;
        }
        _workers.add(iso);
        _ports.add(port);
      } catch (_) {
        // Keep isolates that already started; liveThreads reports that count.
      }
    }
    final live = _ports.length;
    for (var i = 0; i < live; i++) {
      _ports[i].send({
        'type': 'init',
        'reply': _inbox!.sendPort,
        'workerId': i,
        'stride': live,
        'batch': batchSize < 1 ? 1 : batchSize,
      });
    }
  }

  void setJob(Map<String, dynamic> job) {
    final snap = Map<String, dynamic>.from(job);
    for (var i = 0; i < _ports.length; i++) {
      _ports[i].send({
        'type': 'job',
        'job': snap,
        'workerId': i,
        'stride': _ports.length,
      });
    }
  }

  void go() {
    for (final p in _ports) {
      p.send({'type': 'go'});
    }
  }

  Future<void> stop() async {
    for (final p in _ports) {
      try {
        p.send({'type': 'stop'});
      } catch (_) {}
    }
    for (final iso in _workers) {
      iso.kill(priority: Isolate.immediate);
    }
    _workers.clear();
    _ports.clear();
    await _sub?.cancel();
    _sub = null;
    _inbox?.close();
    _inbox = null;
  }

  void _onMsg(dynamic msg) {
    if (msg is! Map) return;
    final type = msg['type']?.toString();
    if (type == 'hashed') {
      onHashed?.call((msg['n'] as num?)?.toInt() ?? 0);
      return;
    }
    if (type == 'share') {
      final nonce = msg['nonce']?.toString() ?? '';
      if (nonce.isEmpty) return;
      final raw = msg['job'];
      onShare?.call(
        nonce,
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{},
      );
    }
  }
}

void gnfpHashWorkerMain(SendPort ready) {
  final inbox = ReceivePort();
  ready.send(inbox.sendPort);
  unawaited(_gnfpHashWorkerLoop(inbox));
}

Future<void> _gnfpHashWorkerLoop(ReceivePort inbox) async {
  SendPort? reply;
  var workerId = 0;
  var stride = 1;
  var batch = 32;
  var start = 0;
  var running = true;
  Map<String, dynamic>? job;

  inbox.listen((msg) {
    if (msg is! Map) return;
    switch (msg['type']?.toString()) {
      case 'init':
        reply = msg['reply'] as SendPort?;
        workerId = (msg['workerId'] as num?)?.toInt() ?? 0;
        stride = _atLeast1(msg['stride']);
        batch = _atLeast1(msg['batch']);
        start = workerId;
      case 'job':
        final raw = msg['job'];
        if (raw is Map) {
          job = Map<String, dynamic>.from(raw);
        }
        workerId = (msg['workerId'] as num?)?.toInt() ?? workerId;
        stride = _atLeast1(msg['stride'] ?? stride);
        start = workerId;
      case 'go':
        break;
      case 'stop':
        running = false;
    }
  });

  while (running) {
    final current = job;
    final out = reply;
    if (current != null && out != null) {
      final got = hashNonceRange(current, start, batch, stride);
      start = got.nextNonce;
      if (got.hashes > 0) {
        out.send({'type': 'hashed', 'n': got.hashes});
      }
      for (final nonce in got.shares) {
        out.send({
          'type': 'share',
          'nonce': nonce,
          'job': current,
        });
      }
      await Future<void>.delayed(Duration.zero);
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }
  inbox.close();
}

int _atLeast1(Object? value) {
  final n = value is num ? value.toInt() : 1;
  return n < 1 ? 1 : n;
}
