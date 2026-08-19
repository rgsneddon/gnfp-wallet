/// In-wallet gnfp-mine 1.0.9 stratum client. Credits [user] (gnfp1….worker).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'gnfp_cpu_hash.dart';
import 'gnfp_hash_farm.dart';
import 'gnfp_mine_command.dart';

class InWalletMinerStatus {
  const InWalletMinerStatus({
    this.running = false,
    this.accepted = 0,
    this.rejected = 0,
    this.hashes = 0,
    this.height = 0,
    this.hashrate = 0,
    this.localHashrate = 0,
    this.lastError = '',
    this.user = '',
  });

  final bool running;
  final int accepted;
  final int rejected;
  final int hashes;
  final int height;
  final double hashrate;
  final double localHashrate;
  final String lastError;
  final String user;
}

typedef SecureConnect = Future<Socket> Function(String host, int port);

class InWalletMiner {
  InWalletMiner({
    this.connect,
    this.maxHashesPerTick = 256,
    this.reconnectDelay = const Duration(seconds: 2),
    this.statsEvery = const Duration(seconds: 1),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final SecureConnect? connect;
  final int maxHashesPerTick;
  final Duration reconnectDelay;
  final Duration statsEvery;
  final DateTime Function() _now;

  Socket? _sock;
  Timer? _tick;
  Timer? _stats;
  Timer? _reconnect;
  GnfpHashFarm? _farm;
  String _buf = '';
  Map<String, dynamic>? _job;
  WalletMineCommand? _cmd;
  DateTime? _firstHashAt;
  DateTime? _startedAt;
  DateTime? _lastEmit;
  int _nonce = 0;
  int _accepted = 0;
  int _rejected = 0;
  int _hashes = 0;
  int _bits = 1;
  int _height = 0;
  String _error = '';
  bool _wantRun = false;
  bool _running = false;
  bool _holdSubmit = false;
  bool _hashing = false;
  final _pendingShares = <({String nonce, Map<String, dynamic> job})>[];
  static const _maxQueued = 8;
  final _updates = StreamController<InWalletMinerStatus>.broadcast();

  Stream<InWalletMinerStatus> get updates => _updates.stream;

  /// Isolates actually hashing on this device — never requested --threads.
  int get liveThreads {
    final farm = _farm;
    if (farm != null && farm.isRunning) return farm.threads;
    if (_wantRun && _running && _cmd != null) return 1;
    return 0;
  }

  InWalletMinerStatus get status => InWalletMinerStatus(
        running: _running,
        accepted: _accepted,
        rejected: _rejected,
        hashes: _hashes,
        height: _height,
        hashrate: _rate,
        localHashrate: _localRate,
        lastError: _error,
        user: _cmd?.user ?? '',
      );

  double get _rate {
    final start = _firstHashAt;
    if (start == null || _accepted <= 0) return 0;
    final sec = _now().difference(start).inMilliseconds / 1000;
    if (sec <= 0) return 0;
    return verifiedWorkRate(accepted: _accepted, bits: _bits, elapsedSec: sec);
  }

  double get _localRate {
    if (_hashes <= 0) return 0;
    final start = _startedAt ?? _firstHashAt;
    if (start == null) return 0;
    final sec = _now().difference(start).inMilliseconds / 1000;
    if (sec <= 0) return 0;
    return _hashes / sec;
  }

  /// Starts hashing as [cmd.user] so pool credit lands on that gnfp1.
  Future<InWalletMinerStatus> start(WalletMineCommand cmd) async {
    await stop();
    _cmd = cmd;
    _wantRun = true;
    _running = true;
    _error = '';
    _accepted = 0;
    _rejected = 0;
    _hashes = 0;
    _bits = 1;
    _nonce = 0;
    _holdSubmit = false;
    _pendingShares.clear();
    _firstHashAt = null;
    _startedAt = _now();
    _emit(force: true);
    await _startFarm(cmd.threads);
    await _openSocket();
    return status;
  }

  Future<void> _startFarm(int threads) async {
    await _farm?.stop();
    _farm = null;
    final farm = GnfpHashFarm(
      batchSize: maxHashesPerTick < 1 ? 1 : maxHashesPerTick,
      onHashed: _onFarmHashed,
      onShare: _onFarmShare,
    );
    try {
      await farm.start(threads);
      if (!_wantRun) {
        await farm.stop();
        return;
      }
      _farm = farm;
    } catch (_) {
      await farm.stop();
      _farm = null;
    }
  }

  void _onFarmHashed(int n) {
    if (!_wantRun || n <= 0) return;
    _hashes += n;
    _emit();
  }

  void _onFarmShare(String nonce, Map<String, dynamic> job) {
    _submitShare(nonce, job);
  }

  Future<void> _openSocket() async {
    if (!_wantRun) return;
    final cmd = _cmd;
    if (cmd == null) return;
    _tearSocket();
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
      try {
        _sock!.setOption(SocketOption.tcpNoDelay, true);
      } catch (_) {}
      _sock!.listen(_onData, onError: _onSockError, onDone: _onSockDone);
      _send({
        'method': 'login',
        'login': cmd.user,
        'threads': liveThreads,
        'client': gnfpMineClient,
        'version': gnfpMineVersion,
        'algorithm': gnfpMineAlgorithm,
        'id': 1,
        'jsonrpc': '2.0',
      });
      if (_farm == null || !_farm!.isRunning) {
        _tick = Timer.periodic(const Duration(milliseconds: 20), (_) => _hashTick());
      }
      _stats = Timer.periodic(statsEvery, (_) => _sendStats());
      _error = '';
      _running = true;
      if (_job != null) _farm?.setJob(_job!);
      _emit(force: true);
    } catch (e) {
      _scheduleReconnect('$e');
    }
  }

  void _sendStats() {
    final cmd = _cmd;
    if (!_wantRun || cmd == null || _sock == null) return;
    _send({
      'method': 'stats',
      'login': cmd.user,
      'threads': liveThreads,
      'client': gnfpMineClient,
      'version': gnfpMineVersion,
      'algorithm': gnfpMineAlgorithm,
      'jsonrpc': '2.0',
    });
  }

  void _onSockError(Object e) {
    if (!_wantRun) {
      _fail('$e');
      return;
    }
    _scheduleReconnect('');
  }

  void _onSockDone() {
    if (!_wantRun) return;
    _scheduleReconnect('');
  }

  void _scheduleReconnect(String err) {
    _tearSocket();
    if (!_wantRun) return;
    // Stay running. lastError only when a reconnect open actually fails.
    if (err.isNotEmpty) {
      _error = err;
    }
    _running = true;
    _reconnect?.cancel();
    _reconnect = Timer(reconnectDelay, () {
      if (_wantRun) unawaited(_openSocket());
    });
    _emit();
  }

  void _tearSocket() {
    _tick?.cancel();
    _tick = null;
    _stats?.cancel();
    _stats = null;
    final sock = _sock;
    _sock = null;
    _job = null;
    _buf = '';
    if (sock != null) {
      try {
        unawaited(sock.close());
      } catch (_) {
        try {
          sock.destroy();
        } catch (_) {}
      }
    }
  }

  Future<void> stop() async {
    _wantRun = false;
    _reconnect?.cancel();
    _reconnect = null;
    await _farm?.stop();
    _farm = null;
    _tearSocket();
    _running = false;
    _holdSubmit = false;
    _pendingShares.clear();
    _emit(force: true);
  }

  void _fail(String err) {
    _error = err;
    _wantRun = false;
    _reconnect?.cancel();
    _reconnect = null;
    unawaited(_farm?.stop());
    _farm = null;
    _tearSocket();
    _running = false;
    _holdSubmit = false;
    _pendingShares.clear();
    _emit(force: true);
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
      _bits = jobDifficultyBits(msg['difficulty'] ?? _bits);
      _holdSubmit = false;
      _pendingShares.clear();
      _farm?.setJob(msg);
      _farm?.go();
      _emit(force: true);
      _hashTick();
      return;
    }
    final desc = '${msg['description'] ?? msg['result'] ?? msg['error'] ?? ''}'.toLowerCase();
    final formed = msg['formed'] == true ||
        (msg['block'] is Map && msg['block']['formed'] == true) ||
        msg['sealed'] != null;
    if (desc.contains('old_miner_refused') || desc.contains('client_required')) {
      _rejected += 1;
      _holdSubmit = false;
      _error = gnfpMineOldMinerHint;
      _farm?.go();
      _flushPending();
      _emit(force: true);
      return;
    }
    if (desc.contains('worker_too') || desc.contains('worker_invalid')) {
      _rejected += 1;
      _holdSubmit = false;
      _farm?.go();
      _flushPending();
      _emit(force: true);
      return;
    }
    // Pool login is code=0 "Login Successful". Share ack is "accepted" (code=1).
    if (formed) {
      _accepted += 1;
      _firstHashAt ??= _now();
      _holdSubmit = false;
      _farm?.go();
      _flushPending();
      _emit(force: true);
    } else if (desc.contains('accept')) {
      _accepted += 1;
      _firstHashAt ??= _now();
      _holdSubmit = false;
      _farm?.go();
      _flushPending();
      _emit(force: true);
    } else if (desc.contains('reject')) {
      _rejected += 1;
      _holdSubmit = false;
      _farm?.go();
      _flushPending();
      _emit(force: true);
    }
  }

  void _flushPending() {
    if (_holdSubmit || _pendingShares.isEmpty) return;
    final next = _pendingShares.removeAt(0);
    _sendShare(next.nonce, next.job);
  }

  void _submitShare(String nonce, Map<String, dynamic> job) {
    final cmd = _cmd;
    if (!_wantRun || cmd == null || _sock == null) return;
    if (_holdSubmit) {
      if (_pendingShares.length >= _maxQueued) return;
      _pendingShares.add((nonce: nonce, job: job));
      return;
    }
    _sendShare(nonce, job);
  }

  void _sendShare(String nonce, Map<String, dynamic> job) {
    final cmd = _cmd;
    if (!_wantRun || cmd == null || _sock == null) return;
    _holdSubmit = true;
    _send({
      'method': 'submit',
      'login': cmd.user,
      'threads': liveThreads,
      'client': gnfpMineClient,
      'version': gnfpMineVersion,
      'algorithm': gnfpMineAlgorithm,
      'id': job['jobId'] ?? job['id'] ?? '1',
      'nonce': nonce,
      'output': '',
      'jobId': job['jobId'] ?? job['id'] ?? '1',
      'jsonrpc': '2.0',
    });
  }

  /// Local fallback when isolate workers cannot start. One main-isolate hasher.
  void _hashTick() {
    if (_farm != null && _farm!.isRunning) return;
    final job = _job;
    final cmd = _cmd;
    if (!_wantRun || !_running || job == null || cmd == null || _hashing) return;
    _hashing = true;
    try {
      final budget = maxHashesPerTick < 1 ? 1 : maxHashesPerTick;
      final got = hashNonceRange(job, _nonce + 1, budget, 1);
      _nonce = got.nextNonce - 1;
      _hashes += got.hashes;
      if (got.shares.isNotEmpty) {
        _submitShare(got.shares.first, job);
      }
      _emit();
    } finally {
      _hashing = false;
    }
  }

  void _emit({bool force = false}) {
    if (_updates.isClosed) return;
    final now = _now();
    if (!force &&
        _lastEmit != null &&
        now.difference(_lastEmit!) < const Duration(milliseconds: 200)) {
      return;
    }
    _lastEmit = now;
    _updates.add(status);
  }
}
