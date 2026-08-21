/// Command-line GNFP wallet. Verbs match the public help tree.
///
/// Address/seed, session, pool book, and miner command all go through the
/// same units the GUI wallet uses.
library;

import 'dart:io';
import 'dart:math';

import 'gnfp_ledger.dart';
import 'gnfp_mine_command.dart';
import 'gnfp_pool_client.dart';
import 'gnfp_session.dart';

class GnfpCliVerb {
  const GnfpCliVerb(this.name, this.help);
  final String name;
  final String help;
}

/// Screenshot canon: names + one-line meanings.
const gnfpCliVerbs = <GnfpCliVerb>[
  GnfpCliVerb('new', 'Create a new seed + address'),
  GnfpCliVerb('restore', 'Restore from an existing hex seed'),
  GnfpCliVerb('show', 'Print seed and address'),
  GnfpCliVerb('balance', 'Query live spendable balance'),
  GnfpCliVerb('history', 'Query address history'),
  GnfpCliVerb('tip', 'Query network tip'),
  GnfpCliVerb('send', 'Send GNFP via the official pool book'),
  GnfpCliVerb('mine-cmd', 'Print a miner command for this address'),
];

String gnfpCliUsageLine() {
  final names = gnfpCliVerbs.map((v) => v.name).join(',');
  return 'usage: gnfp-cli [-h] {$names} ...';
}

String gnfpCliHelp() {
  final buf = StringBuffer();
  buf.writeln(gnfpCliUsageLine());
  buf.writeln();
  buf.writeln('Command-line GNFP wallet');
  buf.writeln();
  buf.writeln('positional arguments:');
  buf.writeln('  {${gnfpCliVerbs.map((v) => v.name).join(',')}}');
  for (final v in gnfpCliVerbs) {
    buf.writeln('    ${v.name.padRight(16)}${v.help}');
  }
  buf.writeln();
  buf.writeln('options:');
  buf.writeln('  -h, --help            show this help message and exit');
  buf.writeln('  --store PATH          session JSON (default: platform GNFP store)');
  buf.writeln('  --pool URL            book origin (default: $gnfpPoolUrl)');
  buf.writeln('  --to ADDRESS          send destination gnfp1 (send)');
  buf.writeln('  --amount N            send amount in GNFP (send)');
  buf.writeln('  --threads N           miner thread count (mine-cmd)');
  return buf.toString();
}

class GnfpCliParse {
  const GnfpCliParse({
    required this.help,
    this.verb,
    this.store,
    this.pool,
    this.seed,
    this.to,
    this.amount,
    this.threads = gnfpMineDefaultThreads,
    this.error,
  });

  final bool help;
  final String? verb;
  final String? store;
  final String? pool;
  final String? seed;
  final String? to;
  final double? amount;
  final int threads;
  final String? error;
}

GnfpCliParse parseGnfpCliArgs(List<String> args) {
  var help = false;
  String? verb;
  String? store;
  String? pool;
  String? seed;
  String? to;
  double? amount;
  var threads = gnfpMineDefaultThreads;
  final rest = <String>[];

  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '-h' || a == '--help' || a == 'help') {
      help = true;
      continue;
    }
    if (a == '--store') {
      if (i + 1 >= args.length) {
        return const GnfpCliParse(help: false, error: '--store needs a path');
      }
      store = args[++i];
      continue;
    }
    if (a == '--pool') {
      if (i + 1 >= args.length) {
        return const GnfpCliParse(help: false, error: '--pool needs a URL');
      }
      pool = args[++i];
      continue;
    }
    if (a == '--to') {
      if (i + 1 >= args.length) {
        return const GnfpCliParse(help: false, error: '--to needs an address');
      }
      to = args[++i];
      continue;
    }
    if (a == '--amount') {
      if (i + 1 >= args.length) {
        return const GnfpCliParse(help: false, error: '--amount needs a number');
      }
      amount = double.tryParse(args[++i]);
      if (amount == null) {
        return const GnfpCliParse(help: false, error: '--amount needs a number');
      }
      continue;
    }
    if (a == '--threads') {
      if (i + 1 >= args.length) {
        return const GnfpCliParse(help: false, error: '--threads needs a number');
      }
      threads = int.tryParse(args[++i]) ?? threads;
      continue;
    }
    if (a == '--seed') {
      if (i + 1 >= args.length) {
        return const GnfpCliParse(help: false, error: '--seed needs a hex seed');
      }
      seed = args[++i];
      continue;
    }
    if (a.startsWith('-')) {
      return GnfpCliParse(help: false, error: 'unknown option $a');
    }
    if (verb == null) {
      verb = a;
    } else {
      rest.add(a);
    }
  }

  if (verb != null && verb != 'help') {
    final known = gnfpCliVerbs.any((v) => v.name == verb);
    if (!known) {
      return GnfpCliParse(help: false, error: 'unknown command $verb', verb: verb);
    }
  } else if (verb == 'help') {
    help = true;
    verb = null;
  }

  if (verb == 'restore' && seed == null && rest.isNotEmpty) {
    seed = rest.removeAt(0);
  }
  if (verb == 'send') {
    if (to == null && rest.isNotEmpty) to = rest.removeAt(0);
    if (amount == null && rest.isNotEmpty) {
      amount = double.tryParse(rest.removeAt(0));
    }
  }

  return GnfpCliParse(
    help: help || (verb == null && store == null && pool == null),
    verb: verb,
    store: store,
    pool: pool,
    seed: seed,
    to: to,
    amount: amount,
    threads: threads,
  );
}

class GnfpCli {
  GnfpCli({
    GnfpLedger? ledger,
    GnfpSession? session,
    StringSink? stdout,
    StringSink? stderr,
    Random? random,
  })  : _injectedLedger = ledger,
        _injectedSession = session,
        out = stdout ?? stdoutIO,
        err = stderr ?? stderrIO,
        _random = random;

  static final StringSink stdoutIO = stdout;
  static final StringSink stderrIO = stderr;

  final GnfpLedger? _injectedLedger;
  final GnfpSession? _injectedSession;
  final StringSink out;
  final StringSink err;
  final Random? _random;

  GnfpLedger? _ledger;
  GnfpSession? _session;

  Future<int> run(List<String> args) async {
    final parsed = parseGnfpCliArgs(args);
    if (parsed.error != null) {
      err.writeln(parsed.error);
      err.write(gnfpCliHelp());
      return 2;
    }
    if (parsed.help) {
      out.write(gnfpCliHelp());
      return 0;
    }
    _session = _injectedSession ??
        GnfpSession(
          store: parsed.store != null ? File(parsed.store!) : null,
          random: _random,
        );
    _ledger = _injectedLedger ??
        GnfpLedger(
          pool: GnfpPoolClient(baseUrl: parsed.pool ?? gnfpPoolUrl),
          random: _random,
        );
    await _session!.load(_ledger!);
    switch (parsed.verb) {
      case 'new':
        return _new();
      case 'restore':
        return _restore(parsed.seed);
      case 'show':
        return _show();
      case 'balance':
        return _balance();
      case 'history':
        return _history();
      case 'tip':
        return _tip();
      case 'send':
        return _send(parsed.to, parsed.amount);
      case 'mine-cmd':
        return _mineCmd(parsed.threads);
      default:
        out.write(gnfpCliHelp());
        return 0;
    }
  }

  Future<int> _new() async {
    final session = _session!;
    final ledger = _ledger!;
    if (session.store.existsSync()) {
      session.store.deleteSync();
    }
    session.seed = null;
    session.address = null;
    session.extra = {};
    final addr = await session.ensureAddress(ledger);
    out.writeln('Address: ${addr.value}');
    out.writeln('Seed:    ${session.seed}');
    return 0;
  }

  Future<int> _restore(String? seed) async {
    final hex = (seed ?? '').trim();
    if (hex.isEmpty) {
      err.writeln('restore needs a hex seed');
      return 2;
    }
    final session = _session!;
    final ledger = _ledger!;
    final addr = ledger.createAddress(seed: hex);
    await session.rememberAddress(ledger, addr, seed: hex);
    out.writeln('Address: ${addr.value}');
    out.writeln('Seed:    ${session.seed}');
    return 0;
  }

  Future<int> _show() async {
    final session = _session!;
    final ledger = _ledger!;
    final addr = session.address ?? await session.load(ledger);
    if (addr == null || session.seed == null) {
      err.writeln('no session — run gnfp-cli new or gnfp-cli restore <hex>');
      return 1;
    }
    out.writeln('Seed:    ${session.seed}');
    out.writeln('Address: ${addr.value}');
    return 0;
  }

  Future<int> _needAddress() async {
    final session = _session!;
    final ledger = _ledger!;
    if (session.address != null) return 0;
    final loaded = await session.load(ledger);
    if (loaded == null) {
      err.writeln('no session — run gnfp-cli new or gnfp-cli restore <hex>');
      return 1;
    }
    return 0;
  }

  Future<int> _balance() async {
    if (await _needAddress() != 0) return 1;
    final addr = _session!.address!;
    final n = await _ledger!.pool.balance(addr.value);
    out.writeln('Address: ${addr.value}');
    out.writeln('Coin:    $gnfpTicker');
    out.writeln('Balance: $n');
    return 0;
  }

  Future<int> _history() async {
    if (await _needAddress() != 0) return 1;
    final addr = _session!.address!;
    final rows = await _ledger!.syncOwnerHistory(addr);
    if (rows.isEmpty) {
      out.writeln('No movements on this address yet.');
      return 0;
    }
    for (final row in rows) {
      out.writeln(
        '${row.kind}\t${row.amount} $gnfpTicker\t${row.from} -> ${row.to}'
        '${row.height != null ? '\theight ${row.height}' : ''}',
      );
    }
    return 0;
  }

  Future<int> _tip() async {
    Map<String, dynamic> json;
    try {
      json = await _ledger!.pool.get('/api/tip');
    } catch (_) {
      json = await _ledger!.pool.get('/api/network');
    }
    final height = GnfpPoolClient.parseNetworkTip(json);
    final ticker = json['ticker']?.toString() ?? gnfpTicker;
    out.writeln('ticker=$ticker');
    out.writeln('height=$height');
    out.writeln('tip=$height');
    return 0;
  }

  Future<int> _send(String? toRaw, double? amount) async {
    if (await _needAddress() != 0) return 1;
    if (toRaw == null || toRaw.trim().isEmpty || amount == null) {
      err.writeln('send needs --to gnfp1… and --amount N');
      return 2;
    }
    final to = GnfpAddress(toRaw.trim());
    if (!to.isValid) {
      err.writeln('not a GNFP address');
      return 2;
    }
    final from = _session!.address!;
    final tx = await _ledger!.send(from: from, to: to, amount: amount);
    out.writeln('id:     ${tx.id}');
    out.writeln('from:   ${tx.from}');
    out.writeln('to:     ${tx.to}');
    out.writeln('amount: ${tx.amount} $gnfpTicker');
    return 0;
  }

  Future<int> _mineCmd(int threads) async {
    if (await _needAddress() != 0) return 1;
    final cmd = buildWalletMineCommand(
      address: _session!.address!.value,
      threads: threads,
    );
    if (cmd == null) {
      err.writeln('could not build miner command');
      return 1;
    }
    out.writeln(cmd.command);
    return 0;
  }
}

Future<int> runGnfpCli(
  List<String> args, {
  GnfpLedger? ledger,
  GnfpSession? session,
  StringSink? stdout,
  StringSink? stderr,
  Random? random,
}) {
  return GnfpCli(
    ledger: ledger,
    session: session,
    stdout: stdout,
    stderr: stderr,
    random: random,
  ).run(args);
}
