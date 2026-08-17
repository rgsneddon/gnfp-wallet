/// Persist seed/address so the same gnfp1 returns on next launch.
/// No login name — the wallet is seed-backed only.
/// App updates must reuse this store so spendable book balances stay on the
/// same address.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'gnfp_ledger.dart';

/// Load a session for wallet boot. I/O errors return null so the shell can
/// still become ready.
Future<GnfpAddress?> bootLoad(GnfpSession session, GnfpLedger ledger) async {
  try {
    return await session.load(ledger);
  } catch (_) {
    return null;
  }
}

class GnfpSessionRecord {
  const GnfpSessionRecord({this.seed, this.address});
  final String? seed;
  final String? address;
}

class GnfpSession {
  GnfpSession({File? store, Random? random, List<File>? legacyStores})
      : store = store ?? defaultStore(),
        _random = random ?? Random.secure(),
        _legacyStores = legacyStores ?? const [];

  final File store;
  final Random _random;
  final List<File> _legacyStores;
  String? seed;
  GnfpAddress? address;
  Map<String, dynamic> extra = {};

  /// Application Support is writable in a Mac App Sandbox container.
  static String macDefaultStorePath(String home) {
    final h = home.isEmpty ? '.' : home;
    final trimmed = h.endsWith('/') ? h.substring(0, h.length - 1) : h;
    return '$trimmed/Library/Application Support/GNFP/session.json';
  }

  static File defaultStore() {
    if (Platform.isWindows) {
      final root = Platform.environment['APPDATA'] ?? '.';
      return File('$root${Platform.pathSeparator}GNFP${Platform.pathSeparator}session.json');
    }
    final home = Platform.environment['HOME'] ?? '.';
    if (Platform.isMacOS) {
      return File(macDefaultStorePath(home));
    }
    return File('$home/.gnfp/session.json');
  }

  /// Older Mac / Linux drops that a version bump must still find.
  static List<File> defaultLegacyStores({String? home}) {
    final h = (home ?? Platform.environment['HOME'] ?? '').trim();
    if (h.isEmpty) return const [];
    final trimmed = h.endsWith('/') ? h.substring(0, h.length - 1) : h;
    return [
      File('$trimmed/.gnfp/session.json'),
      File('$trimmed/Library/Application Support/gnfp/session.json'),
      File('$trimmed/Library/Application Support/gnfp_wallet/session.json'),
      File(
        '$trimmed/Library/Containers/online.restoreprivacy.gnfpWallet/Data/Library/Application Support/GNFP/session.json',
      ),
    ];
  }

  /// Read any historical session JSON. Never invent an address.
  static GnfpSessionRecord? parseStore(Object? raw) {
    if (raw is! Map) return null;
    String? pick(List<String> keys) {
      for (final key in keys) {
        final v = raw[key]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return null;
    }

    var addr = pick(const [
      'address',
      'addr',
      'gnfpAddress',
      'gnfp',
      'payout',
      'payoutAddress',
    ]);
    if (addr != null && !addr.startsWith(gnfpAddressPrefix)) {
      addr = null;
    }
    var seed = pick(const ['seed', 'hexSeed']);
    if (addr == null) {
      final phrase = pick(const ['phrase', 'backup', 'backupPhrase', 'words']);
      if (phrase != null && phrase.contains(' ')) {
        try {
          addr = restoreFromPhrase(phrase).value;
        } catch (_) {
          /* leave null — do not mint */
        }
      }
    }
    if ((seed == null || seed.isEmpty) && addr == null) return null;
    return GnfpSessionRecord(seed: seed, address: addr);
  }

  /// Create or restore the local address without a login name.
  /// Never rotates a recovered gnfp1 when the app version changes.
  Future<GnfpAddress> ensureAddress(GnfpLedger ledger) async {
    final loaded = await load(ledger);
    if (loaded != null) {
      await persist();
      return loaded;
    }
    for (final legacy in _effectiveLegacy()) {
      final prior = GnfpSession(store: legacy);
      final hit = await prior.load(ledger);
      if (hit != null) {
        seed = prior.seed;
        address = hit;
        extra = Map<String, dynamic>.from(prior.extra);
        await persist();
        return hit;
      }
    }
    seed = List.generate(16, (_) => _random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    address = ledger.createAddress(seed: seed);
    await persist();
    return address!;
  }

  List<File> _effectiveLegacy() {
    if (_legacyStores.isNotEmpty) return _legacyStores;
    if (store.path == defaultStore().path) return defaultLegacyStores();
    return const [];
  }

  Future<GnfpAddress> rememberAddress(GnfpLedger ledger, GnfpAddress next) async {
    address = next;
    seed ??= next.value;
    ledger.adopt(next);
    await persist();
    return next;
  }

  Future<GnfpAddress?> load(GnfpLedger ledger) async {
    try {
      if (!store.existsSync()) return null;
      final data = jsonDecode(store.readAsStringSync());
      if (data is! Map) return null;
      extra = Map<String, dynamic>.from(data);
      extra.remove('login');
      extra.remove('loginName');
      final rec = parseStore(data);
      if (rec == null) return null;
      seed = rec.seed ?? seed;
      if (rec.address != null && rec.address!.startsWith(gnfpAddressPrefix)) {
        address = GnfpAddress(rec.address!);
        ledger.adopt(address!);
        return address;
      }
      if (seed == null || seed!.isEmpty) return null;
      address = ledger.createAddress(seed: seed);
      return address;
    } catch (_) {
      return null;
    }
  }

  Future<void> persist() async {
    try {
      store.parent.createSync(recursive: true);
      extra['seed'] = seed;
      extra['address'] = address?.value;
      extra['schema'] = 2;
      extra.remove('login');
      extra.remove('loginName');
      store.writeAsStringSync(jsonEncode(extra));
    } catch (_) {
      // Locked or unwritable store must not abort first-frame boot.
    }
  }
}
