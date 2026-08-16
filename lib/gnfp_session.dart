/// Persist seed/address so the same gnfp1 returns on next launch.
/// No login name — the wallet is seed-backed only.
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

class GnfpSession {
  GnfpSession({File? store, Random? random})
      : store = store ?? defaultStore(),
        _random = random ?? Random.secure();

  final File store;
  final Random _random;
  String? seed;
  GnfpAddress? address;

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

  /// Create or restore the local address without a login name.
  Future<GnfpAddress> ensureAddress(GnfpLedger ledger) async {
    final loaded = await load(ledger);
    if (loaded != null) return loaded;
    seed = List.generate(16, (_) => _random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    address = ledger.createAddress(seed: seed);
    await persist();
    return address!;
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
      seed = data['seed']?.toString();
      final stored = data['address']?.toString();
      if (stored != null && stored.startsWith(gnfpAddressPrefix)) {
        address = GnfpAddress(stored);
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
      store.writeAsStringSync(
        jsonEncode({
          'seed': seed,
          'address': address?.value,
        }),
      );
    } catch (_) {
      // Locked or unwritable store must not abort first-frame boot.
    }
  }
}
