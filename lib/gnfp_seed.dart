/// 12-word BIP-39 English mnemonic helpers.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'gnfp_bip39_english.dart';

const gnfpSeedWordCount = 12;
const gnfpWrongPhraseWarning =
    'A wrong 12-word phrase creates a new empty wallet. The current boxes show this wallet. Check every word before restore.';

List<String> gnfpPhraseWords(String phrase) {
  return phrase
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
}

bool gnfpPhraseEquals(String a, String b) {
  final left = gnfpPhraseWords(a);
  final right = gnfpPhraseWords(b);
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

String hexEncodeBytes(List<int> bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

Uint8List phraseEntropy({required String addressValue, String? seed}) {
  final material = '${seed ?? ''}|$addressValue';
  final digest = sha256.convert(utf8.encode('gnfp-bip39:$material')).bytes;
  return Uint8List.fromList(digest.sublist(0, 16));
}

/// 128-bit entropy → 12 BIP-39 English words.
String encodeBip39(List<int> entropy) {
  if (entropy.length != 16) {
    throw ArgumentError('BIP-39 12-word entropy must be 16 bytes');
  }
  final hash = sha256.convert(entropy).bytes[0];
  final bits = <int>[];
  for (final b in entropy) {
    for (var i = 7; i >= 0; i--) {
      bits.add((b >> i) & 1);
    }
  }
  for (var i = 7; i >= 4; i--) {
    bits.add((hash >> i) & 1);
  }
  final words = <String>[];
  for (var w = 0; w < 12; w++) {
    var idx = 0;
    for (var i = 0; i < 11; i++) {
      idx = (idx << 1) | bits[w * 11 + i];
    }
    words.add(bip39English[idx]);
  }
  return words.join(' ');
}

Uint8List decodeBip39(List<String> words) {
  if (words.length != 12) {
    throw ArgumentError('need 12 words');
  }
  final bits = <int>[];
  for (final w in words) {
    final idx = bip39English.indexOf(w);
    if (idx < 0) throw ArgumentError('unknown word');
    for (var i = 10; i >= 0; i--) {
      bits.add((idx >> i) & 1);
    }
  }
  final entropy = Uint8List(16);
  for (var i = 0; i < 16; i++) {
    var v = 0;
    for (var b = 0; b < 8; b++) {
      v = (v << 1) | bits[i * 8 + b];
    }
    entropy[i] = v;
  }
  final hash = sha256.convert(entropy).bytes[0];
  var cs = 0;
  for (var i = 0; i < 4; i++) {
    cs = (cs << 1) | bits[128 + i];
  }
  if (cs != (hash >> 4)) throw ArgumentError('bad checksum');
  return entropy;
}

Uint8List entropyFromAnyPhrase(List<String> parts) {
  if (parts.length == 12) {
    try {
      return decodeBip39(parts);
    } catch (_) {}
  }
  return Uint8List.fromList(
    sha256.convert(utf8.encode(parts.join(' '))).bytes.sublist(0, 16),
  );
}
