/// GNFP chain ledger — send, receive, and mining-receive on GNFP addresses.
///
/// Spendable asset is always GNFP (never PERC). Addresses are `gnfp1` + hex.
/// Money ops go through the live pool wallet API.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'gnfp_owner_ledger.dart';
import 'gnfp_pool_client.dart';
import 'gnfp_seed.dart';

const gnfpTicker = 'GNFP';
const gnfpAddressPrefix = 'gnfp1';
const gnfpStratum = 'de.restoreprivacy.online:1474';
const gnfpPoolUrl = 'https://gnfp.restoreprivacy.online';
/// Live gnfp-mine payout address. Miner credit reads this book, not a faucet.
const gnfpMinerPayout = 'gnfp18ff7e8b2f0ef3e96f598231638aafd5a5abc490c';

class GnfpAddress {
  const GnfpAddress(this.value);
  final String value;

  bool get isValid =>
      value.startsWith(gnfpAddressPrefix) &&
      value.length >= gnfpAddressPrefix.length + 16 &&
      !value.toLowerCase().contains('perc');

  @override
  String toString() => value;
}

class GnfpTx {
  const GnfpTx({
    required this.id,
    required this.from,
    required this.to,
    required this.amount,
    required this.kind,
    this.memo = '',
    this.height,
    this.foundAt,
    this.confirmed,
  });

  final String id;
  final String from;
  final String to;
  final double amount;
  final String kind;
  final String memo;
  final int? height;
  final int? foundAt;
  /// null = legacy row (visible). false = in-round micro, omitted from explorer.
  final bool? confirmed;

  factory GnfpTx.fromJson(Map<String, dynamic> json) {
    return GnfpTx(
      id: json['id']?.toString() ?? '',
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      kind: json['kind']?.toString() ?? '',
      memo: json['memo']?.toString() ?? '',
      height: (json['height'] as num?)?.toInt(),
      foundAt: (json['foundAt'] as num?)?.toInt(),
      confirmed: json['confirmed'] is bool ? json['confirmed'] as bool : null,
    );
  }
}

class GnfpLedger {
  GnfpLedger({Random? random, GnfpPoolClient? pool})
      : _random = random ?? Random.secure(),
        pool = pool ?? GnfpPoolClient();

  final Random _random;
  final GnfpPoolClient pool;
  final Map<String, double> _balances = {};
  final Map<String, double> _pendingMining = {};
  final List<GnfpTx> _txs = [];
  int? lastTip;

  Iterable<GnfpTx> get transactions => List.unmodifiable(_txs);

  /// Plaintext owner ledger for [address] from local book-backed txs.
  List<OwnerLedgerRow> ownerRows(GnfpAddress address) =>
      ownerLedgerRows(address: address.value, txs: _txs);

  /// Pull owner-visible history from the book wallet API and merge.
  Future<List<OwnerLedgerRow>> syncOwnerHistory(GnfpAddress address) async {
    try {
      final json = await pool.history(address.value);
      final rows = ownerLedgerRows(
        address: address.value,
        txs: (json['txs'] as List?) ?? const [],
      );
      for (final row in rows) {
        final next = GnfpTx(
          id: row.id,
          from: row.from,
          to: row.to,
          amount: row.amount,
          kind: row.kind,
          memo: row.memo,
          height: row.height,
          foundAt: row.foundAt,
          confirmed: true,
        );
        final i = _txs.indexWhere((t) => t.id == row.id);
        if (i >= 0) {
          _txs[i] = next;
        } else {
          _txs.add(next);
        }
      }
      return ownerRows(address);
    } catch (_) {
      return ownerRows(address);
    }
  }

  /// Live chain height from the pool tip/network book. Caches [lastTip].
  Future<int> networkTip() async {
    final n = await pool.networkTip();
    lastTip = n;
    return n;
  }

  GnfpAddress createAddress({String? seed}) {
    final raw = seed ??
        List.generate(16, (_) => _random.nextInt(256))
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
    final digest = sha256.convert(utf8.encode('gnfp:$raw')).toString();
    final addr = GnfpAddress('$gnfpAddressPrefix${digest.substring(0, 40)}');
    _balances.putIfAbsent(addr.value, () => 0);
    return addr;
  }

  double balance(GnfpAddress address) => _balances[address.value] ?? 0;

  /// Unconfirmed hash-bonus for [address] this open round. Not an explorer row.
  double pendingMining(GnfpAddress address) => _pendingMining[address.value] ?? 0;

  void adopt(GnfpAddress address) {
    _balances.putIfAbsent(address.value, () => 0);
  }

  /// Keep a recovered spendable so an update cannot flash zero.
  void rememberSpendable(GnfpAddress address, double amount) {
    if (!address.isValid) return;
    adopt(address);
    final n = amount;
    if (!n.isFinite || n <= 0) return;
    final prev = balance(address);
    if (n > prev) _balances[address.value] = n;
  }

  /// Pull this address's spendable amount from the live book.
  /// App updates keep the same gnfp1. A live 0 never wipes a known amount.
  Future<double> syncSpendable(GnfpAddress address) async {
    if (!address.isValid) {
      throw ArgumentError('not a GNFP address');
    }
    adopt(address);
    final previous = balance(address);
    try {
      final json = await pool.get('/api/wallet/balance?address=${address.value}');
      final live = GnfpPoolClient.parseSpendable(json);
      _pendingMining[address.value] = GnfpPoolClient.parsePending(json);
      if (live > 0) {
        _balances[address.value] = live;
        return balance(address);
      }
      try {
        final hist = await pool.history(address.value);
        final rec = reconstructSpendable(
          address: address.value,
          shear: hist['shear']?.toString() ?? '',
          txs: (hist['txs'] as List?) ?? const [],
        );
        if (rec > 0) {
          _balances[address.value] = rec;
          return rec;
        }
      } catch (_) {
        /* book fetch already returned 0 — keep previous */
      }
      return previous;
    } catch (_) {
      return previous;
    }
  }

  bool get isGnfpChain => true;

  void _apply(GnfpTx tx, {double? fromBal, double? toBal}) {
    _txs.add(tx);
    if (fromBal != null) _balances[tx.from] = fromBal;
    if (toBal != null) {
      _balances[tx.to] = toBal;
    } else if (tx.kind != 'send') {
      _balances[tx.to] = balance(GnfpAddress(tx.to)) + tx.amount;
    }
  }

  /// Closed: the wallet must not mint GNFP to self. Incoming value is
  /// peer [send] or [creditFromMiner] only.
  Future<GnfpTx> receive({
    required GnfpAddress to,
    required double amount,
    String from = 'external',
    String memo = 'receive',
  }) async {
    throw StateError('self_mint_forbidden');
  }

  Future<GnfpTx> send({
    required GnfpAddress from,
    required GnfpAddress to,
    required double amount,
    String memo = '',
  }) async {
    if (!from.isValid || !to.isValid) {
      throw ArgumentError('GNFP addresses required');
    }
    if (amount <= 0) {
      throw ArgumentError('amount must be positive');
    }
    final json = await pool.send(
      from: from.value,
      to: to.value,
      amount: amount,
      memo: memo,
    );
    final tx = GnfpTx.fromJson(Map<String, dynamic>.from(json['tx'] as Map));
    _apply(
      tx,
      fromBal: (json['fromBalance'] as num?)?.toDouble(),
      toBal: (json['toBalance'] as num?)?.toDouble(),
    );
    return tx;
  }

  Future<GnfpTx> miningReceive({
    required GnfpAddress to,
    required double amount,
    String minerTag = 'miner',
    String? nonce,
    String? solution,
    String? preWork,
  }) async {
    if (!to.isValid) {
      throw ArgumentError('mining credit needs a GNFP address');
    }
    if (nonce == null ||
        nonce.isEmpty ||
        preWork == null ||
        preWork.isEmpty) {
      throw StateError('proof_required');
    }
    final json = await pool.miningReceive(
      to: to.value,
      amount: amount,
      minerTag: minerTag,
      nonce: nonce,
      solution: solution,
      preWork: preWork,
    );
    final tx = GnfpTx.fromJson(Map<String, dynamic>.from(json['tx'] as Map));
    _apply(tx, toBal: (json['balance'] as num?)?.toDouble());
    return tx;
  }

  /// Pull the live pool miner book into this wallet. Does not POST another
  /// credit — mined coins are already on the pool; this is a separate receival
  /// from the scenario / faucet path.
  Future<GnfpTx> creditFromMiner({required GnfpAddress to}) async {
    if (!to.isValid) {
      throw ArgumentError('not a GNFP address');
    }
    final live = await pool.balance(to.value);
    if (live <= 0) {
      throw StateError('no miner book for this address');
    }
    final previous = balance(to);
    final delta = live - previous;
    _balances[to.value] = live;
    final tx = GnfpTx(
      id: 'miner-${DateTime.now().millisecondsSinceEpoch}',
      from: gnfpStratum,
      to: to.value,
      amount: delta > 0 ? delta : 0,
      kind: 'miner',
      memo: 'credit from your miner',
    );
    if (delta > 0) {
      _txs.add(tx);
    }
    return tx;
  }

  Future<void> refresh() async {
    final kept = Map<String, double>.from(_balances);
    try {
      final snap = await pool.snapshot();
      final incoming = (snap['balances'] as Map? ?? {}).map(
        (k, v) => MapEntry(
          k.toString(),
          v is num ? v.toDouble() : (double.tryParse('$v') ?? 0),
        ),
      );
      if (incoming.isEmpty) return;
      for (final e in incoming.entries) {
        final prev = kept[e.key] ?? 0;
        _balances[e.key] = e.value > 0 ? e.value : prev;
      }
      if (snap['txs'] is List) {
        _txs
          ..clear()
          ..addAll(
            ((snap['txs'] as List?) ?? []).map(
              (row) => GnfpTx.fromJson(Map<String, dynamic>.from(row as Map)),
            ),
          );
      }
    } catch (_) {
      _balances
        ..clear()
        ..addAll(kept);
    }
  }

  Map<String, dynamic> snapshot() => {
        'ticker': gnfpTicker,
        'stratum': gnfpStratum,
        'pool': gnfpPoolUrl,
        'balances': Map<String, double>.from(_balances),
        'txs': _txs
            .map((t) => {
                  'id': t.id,
                  'from': t.from,
                  'to': t.to,
                  'amount': t.amount,
                  'kind': t.kind,
                  'memo': t.memo,
                  if (t.height != null) 'height': t.height,
                  if (t.foundAt != null) 'foundAt': t.foundAt,
                })
            .toList(),
      };
}

const gnfpBackupWords = [
  'oracle', 'cyan', 'chrono', 'flux', 'god', 'ned', 'fred', 'pedro',
  'beam', 'hash', 'grey', 'night', 'circuit', 'pulse', 'ward', 'vote',
];

/// Twelve English BIP-39 words for this wallet. Production seeds are 16
/// random bytes (32 hex chars); the phrase is those bytes, so restore
/// without the current wallet still yields the same gnfp1.
String backupPhraseFor(GnfpAddress address, {String? seed, int words = 12}) {
  if (words == 40) {
    final hex = address.value.substring(gnfpAddressPrefix.length);
    return hex.split('').map((c) {
      final n = int.parse(c, radix: 16);
      return gnfpBackupWords[n];
    }).join(' ');
  }
  final material = (seed != null && seed.isNotEmpty) ? seed : address.value;
  return encodeBip39(seedToEntropy(material));
}

/// 0.1.6 displayed words as hash(seed|address). Keep matching those on
/// restore so an already-open wallet does not rotate.
String legacyHashedBackupPhrase(GnfpAddress address, {String? seed}) {
  return encodeBip39(phraseEntropy(addressValue: address.value, seed: seed));
}

/// Restore from 12 English words (or a legacy 40-word nibble phrase).
/// Phrase → gnfp1 is invertible with no current wallet. Matching the
/// current displayed (or 0.1.6 hashed) phrase keeps [current]. Any other
/// 12 words mint a new gnfp1 (zero balance until the book has funds).
GnfpAddress restoreFromPhrase(
  String phrase, [
  GnfpLedger? ledger,
  GnfpAddress? current,
  String? currentSeed,
]) {
  final parts = gnfpPhraseWords(phrase);
  if (current != null) {
    final shown = backupPhraseFor(current, seed: currentSeed);
    final hashed = legacyHashedBackupPhrase(current, seed: currentSeed);
    if (gnfpPhraseEquals(phrase, shown) || gnfpPhraseEquals(phrase, hashed)) {
      ledger?.adopt(current);
      return current;
    }
  }
  if (parts.length > 12) {
    final hex = parts.map((w) {
      final i = gnfpBackupWords.indexOf(w);
      if (i < 0) throw ArgumentError('bad phrase word');
      return i.toRadixString(16);
    }).join();
    final addr = GnfpAddress('$gnfpAddressPrefix$hex');
    if (!addr.isValid) throw ArgumentError('phrase is not a GNFP address');
    ledger?.adopt(addr);
    return addr;
  }
  final entropy = entropyFromAnyPhrase(parts);
  final book = ledger ?? GnfpLedger();
  final addr = book.createAddress(seed: hexEncodeBytes(entropy));
  ledger?.adopt(addr);
  return addr;
}

Uint8List qrPayload(GnfpAddress address) =>
    Uint8List.fromList(utf8.encode('gnfp:${address.value}'));
