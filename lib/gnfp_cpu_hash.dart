/// Sequential gnfp-cpu-v1 work hash — same as gnfp-mine 1.0.9 / the Germany book.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const gnfpCpuHashRounds = 8;
const gnfpCpuHashPersonal = 'gnfp-cpu-v1';
const gnfpCpuNonceHexLen = 16;

/// Same rule as the book `jobDifficultyBits`: 0 / missing → 1; clamp 1–32.
int jobDifficultyBits(Object? difficulty) {
  final n = difficulty is num
      ? difficulty.toInt()
      : int.tryParse('$difficulty') ?? 1;
  if (n < 1) return 1;
  if (n > 32) return 32;
  return n;
}

/// Same public H/s as the pool: accepted × 2^bits / elapsed.
double verifiedWorkRate({
  required int accepted,
  required int bits,
  required double elapsedSec,
}) {
  if (accepted <= 0 || elapsedSec <= 0) return 0;
  return (accepted * (1 << jobDifficultyBits(bits))) / elapsedSec;
}

String clipHashField(String value) {
  if (value.length <= 256) return value;
  return value.substring(0, 256);
}

String normalizeCpuNonce(Object? nonce) {
  var raw = nonce?.toString().trim().toLowerCase() ?? '';
  if (raw.startsWith('0x')) raw = raw.substring(2);
  if (raw.isEmpty || !RegExp(r'^[0-9a-f]+$').hasMatch(raw)) return '';
  if (raw.length > gnfpCpuNonceHexLen) {
    raw = raw.substring(raw.length - gnfpCpuNonceHexLen);
  }
  return raw.padLeft(gnfpCpuNonceHexLen, '0');
}

String gnfpWorkHash(String preWork, String nonce, [String solution = '']) {
  final pre = clipHashField(preWork);
  final n = clipHashField(nonce);
  final sol = clipHashField(solution);
  var acc = sha256.convert(utf8.encode(gnfpCpuHashPersonal + pre + n + sol)).bytes;
  for (var i = 0; i < gnfpCpuHashRounds; i += 1) {
    acc = sha256
        .convert(
          Uint8List.fromList([
            ...acc,
            ...utf8.encode('$i'),
            ...utf8.encode(pre),
            ...utf8.encode(n),
          ]),
        )
        .bytes;
  }
  return acc.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

bool hashMeetsBits(String hash, int bits) {
  final n = bits < 0 ? 0 : (bits > 256 ? 256 : bits);
  if (n == 0) return true;
  final full = n ~/ 4;
  final rem = n % 4;
  if (hash.length < full + (rem == 0 ? 0 : 1)) return false;
  if (full > 0 && hash.substring(0, full) != '0' * full) return false;
  if (rem == 0) return true;
  final v = int.parse(hash[full], radix: 16);
  return v < (1 << (4 - rem));
}

bool hashMeetsJob(Map<String, dynamic> job, String nonce, [String solution = '']) {
  final pre = (job['input'] ?? job['preWork'] ?? '').toString();
  final bits = (job['difficulty'] as num?)?.toInt() ?? 1;
  return hashMeetsBits(gnfpWorkHash(pre, nonce, solution), bits < 1 ? 1 : bits);
}

String nextCpuNonce(int counter) {
  return normalizeCpuNonce(counter.toRadixString(16));
}

class HashRangeResult {
  const HashRangeResult({
    required this.hashes,
    required this.shares,
    required this.nextNonce,
  });

  final int hashes;
  final List<String> shares;
  final int nextNonce;
}

/// Hash [count] nonces from [start], stepping by [stride] (one worker's slice).
HashRangeResult hashNonceRange(
  Map<String, dynamic> job,
  int start,
  int count, [
  int stride = 1,
]) {
  final shares = <String>[];
  var nonce = start < 0 ? 0 : start;
  final step = stride < 1 ? 1 : stride;
  final n = count < 0 ? 0 : count;
  for (var i = 0; i < n; i += 1) {
    final hex = nextCpuNonce(nonce);
    nonce += step;
    if (hex.isNotEmpty && hashMeetsJob(job, hex)) {
      shares.add(hex);
    }
  }
  return HashRangeResult(hashes: n, shares: shares, nextNonce: nonce);
}
