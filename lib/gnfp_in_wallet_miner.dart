/// In-wallet gnfp-mine 1.0.9 stratum client. Credits [user] (gnfp1….worker).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'gnfp_cpu_hash.dart';
import 'gnfp_mine_command.dart';

class InWalletMinerStatus {
  const InWalletMinerStatus({
    this.running = false,
    this.accepted = 0,
    this.rejected = 0,
    this.hashes = 0,
    this.height = 0,
    this.hashrate = 0,
    this.lastError = '',
    this.user = '',
  });

  final bool running;
  final int accepted;
  final int rejected;
  final int hashes;
  final int height;
  final double hashrate;
  final String lastError;
  final String user;
}

typedef SecureConnect = Future<Socket> Function(String host, int port);

class InWalletMiner {
  InWalletMiner({
    this.connect,
    this.maxHashesPerTick = 256,
  });

  final SecureConnect? connect;
  final int maxHashesPerTick;

  Socket? _sock;
  Timer? _tick;
  String _buf = '';
  Map<String, dynamic>? _job;
  WalletMineCommand? _cmd;
  DateTime? _started;
  int _nonce = 0;
  int _accepted = 0;
  int _rejected = 0;
  int _hashes = 0;
  int _height = 0;
  String _error = '';
  bool _running = false;
  final _updates = StreamController<InWalletMinerStatus>.broadcast();

  Stream<InWalletMinerStatus> get updates => _updates.stream;
  InWalletMinerStatus get status => InWalletMinerStatus(
        running: _running,
        accepted: _accepted,
        rejected: _rejected,
        hashes: _hashes,
        height: _height,
        hashrate: _rate,
        lastError: _error,
        user: _cmd?.user ?? '',
      );

  double get _rate {
    final start = _started;
    if (start == null) return 0;
    final sec = DateTime.now().difference(start).inMilliseconds / 1000;
    if (sec <= 0) return 0;
    return _hashes / sec;
  }

  /// Starts hashing as [cmd.user] so pool credit lands on that gnfp1.
  Future<InWalletMinerStatus> start(WalletMineCommand cmd) async {
    await stop();
    _cmd = cmd;
    _running = true;
    _error = '';
    _accepted = 0;
    _rejected = 0;
    _hashes = 0;
    _nonce = 0;
    _started = DateTime.now();
    _emit();
    try {
      final parts = cmd.pool.split(':');
      final host = parts.first;
      final port = int.tryParse(parts.length > 1 ? parts[1] : '1474') ?? 1474;
      final useTls = resolveUseTls(pool: cmd.pool, requestedTls: cmd.tls);
      if (connect != null) {
        _sock = await connect!(host, port);
      } else if (useTls) {
        _sock = await SecureSocket.connect(
          host,
          port,
          onBadCertificate: (_) => true,
        );
      } else {
        _sock = await Socket.connect(host, port);
      }
      _sock!.listen(_onData, onError: (e) => _fail('$e'), onDone: stop);
      _send({
        'method': 'login',
        'login': cmd.user,
        'threads': cmd.threads,
        'client': gnfpMineClient,
        'version': gnfpMineVersion,
        'id': 1,
        'jsonrpc': '2.0',
      });
      _tick = Timer.periodic(const Duration(milliseconds: 20), (_) => _hashTick());
    } catch (e) {
      _fail('$e');
    }
    return status;
  }

  Future<void> stop() async {
    _tick?.cancel();
    _tick = null;
    _running = false;
    try {
      await _sock?.close();
    } catch (_) {}
    _sock = null;
    _job = null;
    _emit();
  }

  void _fail(String err) {
    _error = err;
    _running = false;
    _tick?.cancel();
    _tick = null;
    _emit();
  }

  void _send(Map<String, dynamic> msg) {
    _sock?.add(utf8.encode('${jsonEncode(msg)}\n'));
  }

  void _onData(List<int> chunk) {
    if (_cmd != null &&
        !resolveUseTls(pool: _cmd!.pool, requestedTls: _cmd!.tls) &&
        looksLikeTlsRecord(chunk)) {
      _fail(gnfpMineTlsRequiredMsg);
      return;
    }
    _buf += utf8.decode(chunk, allowMalformed: true);
    while (true) {
      final idx = _buf.indexOf('\n');
      if (idx < 0) break;
      final line = _buf.substring(0, idx).trim();
      _buf = _buf.substring(idx + 1);
      if (line.isEmpty) continue;
      try {
        final msg = jsonDecode(line);
        if (msg is! Map) continue;
        _handle(Map<String, dynamic>.from(msg));
      } catch (_) {}
    }
  }

  void _handle(Map<String, dynamic> msg) {
    if (msg['method'] == 'job' || msg['input'] != null || msg['preWork'] != null) {
      _job = msg;
      _height = (msg['height'] as num?)?.toInt() ?? _height;
      _emit();
      _hashTick();
      return;
    }
    final desc = '${msg['description'] ?? msg['result'] ?? ''}'.toLowerCase();
    if (desc.contains('accept') || msg['code'] == 0) {
      _accepted += 1;
      _emit();
    } else if (desc.contains('reject')) {
      _rejected += 1;
      _emit();
    }
  }

  void _hashTick() {
    final job = _job;
    final cmd = _cmd;
    if (!_running || job == null || cmd == null) return;
    for (var i = 0; i < maxHashesPerTick; i += 1) {
      _nonce += 1;
      _hashes += 1;
      final nonce = nextCpuNonce(_nonce);
      if (!hashMeetsJob(job, nonce)) continue;
      _send({
        'method': 'submit',
        'login': cmd.user,
        'threads': cmd.threads,
        'client': gnfpMineClient,
        'version': gnfpMineVersion,
        'id': job['jobId'] ?? job['id'] ?? '1',
        'nonce': nonce,
        'output': '',
        'jobId': job['jobId'] ?? job['id'] ?? '1',
        'jsonrpc': '2.0',
      });
      break;
    }
    _emit();
  }

  void _emit() {
    if (!_updates.isClosed) _updates.add(status);
  }
}
