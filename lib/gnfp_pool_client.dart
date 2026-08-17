/// HTTP client for the live GNFP pool wallet API.
library;

import 'dart:convert';
import 'dart:io';

import 'gnfp_ledger.dart';

class GnfpPoolClient {
  GnfpPoolClient({this.baseUrl = gnfpPoolUrl, HttpClient? http})
      : _http = http ?? HttpClient();

  final String baseUrl;
  final HttpClient _http;
  static const bookFallback = 'https://explorer.restoreprivacy.online';

  Uri _uri(String path, {String? origin}) {
    final base = origin ?? baseUrl;
    final trimmed = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final tail = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$trimmed$tail');
  }

  bool _needsBook(String path) =>
      path.contains('/wallet/') || path.contains('/bridge/');

  bool _isMissing(int status, Map<String, dynamic> json) =>
      status == 404 || json['reason']?.toString() == 'not_found';

  Future<Map<String, dynamic>> _read(HttpClientResponse res) async {
    final text = await utf8.decodeStream(res);
    final json = jsonDecode(text);
    if (json is! Map<String, dynamic>) {
      throw StateError('bad GNFP pool response');
    }
    return json;
  }

  Future<Map<String, dynamic>> get(String path) async {
    Future<({int status, Map<String, dynamic> json})> hit(String origin) async {
      final req = await _http.getUrl(_uri(path, origin: origin));
      req.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      final res = await req.close();
      return (status: res.statusCode, json: await _read(res));
    }

    var got = await hit(baseUrl);
    if (_needsBook(path) && _isMissing(got.status, got.json) && baseUrl != bookFallback) {
      got = await hit(bookFallback);
    }
    if (got.status >= 400) {
      throw StateError(got.json['reason']?.toString() ?? 'pool error');
    }
    return got.json;
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    Future<({int status, Map<String, dynamic> json})> hit(String origin) async {
      final req = await _http.postUrl(_uri(path, origin: origin));
      req.headers.contentType = ContentType.json;
      req.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      req.add(utf8.encode(jsonEncode(body)));
      final res = await req.close();
      return (status: res.statusCode, json: await _read(res));
    }

    var got = await hit(baseUrl);
    if (_needsBook(path) && _isMissing(got.status, got.json) && baseUrl != bookFallback) {
      got = await hit(bookFallback);
    }
    if (got.status >= 400 || got.json['ok'] == false) {
      throw StateError(got.json['reason']?.toString() ?? 'pool error');
    }
    return got.json;
  }

  Future<Map<String, dynamic>> receive({
    required String to,
    required double amount,
    String from = 'external',
    String memo = 'receive',
  }) =>
      post('/api/wallet/receive', {
        'to': to,
        'amount': amount,
        'from': from,
        'memo': memo,
      });

  Future<Map<String, dynamic>> send({
    required String from,
    required String to,
    required double amount,
    String memo = '',
  }) =>
      post('/api/wallet/send', {
        'from': from,
        'to': to,
        'amount': amount,
        'memo': memo,
      });

  Future<Map<String, dynamic>> miningReceive({
    required String to,
    required double amount,
    String minerTag = 'miner',
    String? nonce,
    String? solution,
    String? preWork,
  }) =>
      post('/api/wallet/mining-receive', {
        'to': to,
        'amount': amount,
        'minerTag': minerTag,
        'nonce': nonce,
        'solution': solution,
        'preWork': preWork,
      });

  /// Live chain height from a pool tip/network JSON map.
  static int parseNetworkTip(Map<String, dynamic> json) {
    for (final key in const ['tipHeight', 'tip', 'height']) {
      final raw = json[key];
      if (raw is num) return raw.toInt();
      if (raw is String) {
        final n = int.tryParse(raw.trim());
        if (n != null) return n;
      }
    }
    return 0;
  }

  Future<int> networkTip() async {
    try {
      return parseNetworkTip(await get('/api/tip'));
    } catch (_) {
      return parseNetworkTip(await get('/api/network'));
    }
  }

  Future<double> balance(String address) async {
    final json = await get('/api/wallet/balance?address=$address');
    return (json['balance'] as num?)?.toDouble() ?? 0;
  }

  Future<Map<String, dynamic>> snapshot() => get('/api/wallet/snapshot');

  Future<Map<String, dynamic>> mix({
    required String fromCoin,
    required String toCoin,
    required String fromAddress,
    required String toAddress,
    required double amount,
  }) =>
      post('/api/bridge/mix', {
        'fromCoin': fromCoin,
        'toCoin': toCoin,
        'fromAddress': fromAddress,
        'toAddress': toAddress,
        'amount': amount,
      });
}
