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

  Uri _uri(String path) {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final tail = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$root$tail');
  }

  Future<Map<String, dynamic>> get(String path) async {
    final req = await _http.getUrl(_uri(path));
    req.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    final res = await req.close();
    final text = await utf8.decodeStream(res);
    final json = jsonDecode(text);
    if (json is! Map<String, dynamic>) {
      throw StateError('bad GNFP pool response');
    }
    if (res.statusCode >= 400) {
      throw StateError(json['reason']?.toString() ?? 'pool error');
    }
    return json;
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final req = await _http.postUrl(_uri(path));
    req.headers.contentType = ContentType.json;
    req.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    req.add(utf8.encode(jsonEncode(body)));
    final res = await req.close();
    final text = await utf8.decodeStream(res);
    final json = jsonDecode(text);
    if (json is! Map<String, dynamic>) {
      throw StateError('bad GNFP pool response');
    }
    if (res.statusCode >= 400 || json['ok'] == false) {
      throw StateError(json['reason']?.toString() ?? 'pool error');
    }
    return json;
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
