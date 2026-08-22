import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gnfp_wallet/gnfp_build_stamp.dart';
import 'package:gnfp_wallet/gnfp_cli.dart';
import 'package:gnfp_wallet/gnfp_ledger.dart';
import 'package:gnfp_wallet/gnfp_mine_command.dart';
import 'package:gnfp_wallet/gnfp_pool_client.dart';
import 'package:gnfp_wallet/gnfp_session.dart';

void main() {
  test('shipped help tree names every screenshot verb with its meaning', () {
    final help = gnfpCliHelp();
    expect(help, startsWith('usage: gnfp-cli [-h] {'));
    expect(
      gnfpCliVerbs.map((v) => v.name).toList(),
      ['new', 'restore', 'show', 'balance', 'history', 'tip', 'send', 'mine-cmd'],
    );
    for (final v in gnfpCliVerbs) {
      expect(help, contains(v.name));
      expect(help, contains(v.help));
    }
    expect(help, contains('Create a new seed + address'));
    expect(help, contains('Restore from an existing hex seed'));
    expect(help, contains('Print seed and address'));
    expect(help, contains('Query live spendable balance'));
    expect(help, contains('Query address history'));
    expect(help, contains('Query network tip'));
    expect(help, contains('Send GNFP via the official pool book'));
    expect(help, contains('Print a miner command for this address'));
    expect(help, contains('-h, --help'));
    expect(help, contains(kGnfpPackageVersion));
    expect(help, contains(gnfpCliVersionLine()));
    expect(File('bin/gnfp_cli.dart').readAsStringSync(), contains('runGnfpCli'));
  });

  test('CLI pin is the shipped GUI pin from pubspec + build stamp', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(r'^version:\s*([0-9.]+)\+', multiLine: true).firstMatch(pubspec)!;
    expect(kGnfpPackageVersion, m.group(1));
    expect(gnfpCliVersionLine(), '\$GNFP core wallet v$kGnfpPackageVersion (cli)');
    expect(gnfpCliHelp(), contains(gnfpCliVersionLine()));
    expect(parseGnfpCliArgs(['--version']).version, isTrue);
    expect(parseGnfpCliArgs(['-V']).version, isTrue);
  });

  test('parseGnfpCliArgs treats -h and --help as help', () {
    expect(parseGnfpCliArgs(['-h']).help, isTrue);
    expect(parseGnfpCliArgs(['--help']).help, isTrue);
    expect(parseGnfpCliArgs([]).help, isTrue);
    expect(parseGnfpCliArgs(['balance']).verb, 'balance');
    expect(parseGnfpCliArgs(['restore', 'abc123']).seed, 'abc123');
    expect(parseGnfpCliArgs(['send', '--to', 'gnfp1ab', '--amount', '1.5']).amount, 1.5);
    expect(parseGnfpCliArgs(['nope']).error, contains('unknown command'));
  });

  test('new restore show mine-cmd drive shipped session/address/mine command', () async {
    final dir = await Directory.systemTemp.createTemp('gnfp-cli-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = File('${dir.path}/session.json');
    final out = StringBuffer();
    final err = StringBuffer();
    final ledger = GnfpLedger(random: Random(7), pool: _SilentPool());
    final session = GnfpSession(store: store, random: Random(7));

    Future<int> cli(List<String> args) => runGnfpCli(
          args,
          ledger: ledger,
          session: session,
          stdout: out,
          stderr: err,
          random: Random(7),
        );

    out.clear();
    expect(await cli(['--help']), 0);
    expect(out.toString(), gnfpCliHelp());

    out.clear();
    expect(await cli(['--version']), 0);
    expect(out.toString().trim(), gnfpCliVersionLine());
    expect(out.toString(), contains(kGnfpPackageVersion));

    out.clear();
    expect(await cli(['new']), 0);
    expect(out.toString(), contains('Address: gnfp1'));
    expect(out.toString(), contains('Seed:'));
    final created = session.address!;
    final seed = session.seed!;
    expect(created.value, ledger.createAddress(seed: seed).value);

    out.clear();
    expect(await cli(['show']), 0);
    expect(out.toString(), contains('Seed:    $seed'));
    expect(out.toString(), contains('Address: ${created.value}'));

    const other = '00112233445566778899aabbccddeeff';
    out.clear();
    expect(await cli(['restore', other]), 0);
    final restored = ledger.createAddress(seed: other);
    expect(session.seed, other);
    expect(session.address!.value, restored.value);
    expect(out.toString(), contains('Address: ${restored.value}'));

    out.clear();
    expect(await cli(['mine-cmd', '--threads', '2']), 0);
    final cmd = buildWalletMineCommand(address: restored.value, threads: 2)!;
    expect(out.toString().trim(), cmd.command);
    expect(out.toString(), contains('gnfp-cminer'));
    expect(out.toString().contains('gnfp-mine'), isFalse);
    expect(out.toString(), contains('de.restoreprivacy.online:1474'));
    expect(out.toString(), contains(restored.value));
  });

  test('balance history tip send drive shipped pool client (no live send)', () async {
    final dir = await Directory.systemTemp.createTemp('gnfp-cli-book-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = File('${dir.path}/session.json');
    const hex = 'aabbccddeeff00112233445566778899';
    final book = _BookPool();
    final ledger = GnfpLedger(pool: book);
    final session = GnfpSession(store: store);
    final addr = ledger.createAddress(seed: hex);
    await session.rememberAddress(ledger, addr, seed: hex);
    book.owner = addr.value;

    final out = StringBuffer();
    final err = StringBuffer();
    Future<int> cli(List<String> args) => runGnfpCli(
          args,
          ledger: ledger,
          session: session,
          stdout: out,
          stderr: err,
        );

    out.clear();
    expect(await cli(['tip']), 0);
    expect(out.toString(), contains('ticker=$gnfpTicker'));
    expect(out.toString(), contains('height=${book.height}'));
    expect(out.toString(), contains('tip=${book.height}'));
    expect(GnfpPoolClient.parseNetworkTip({'tipHeight': book.height}), book.height);

    out.clear();
    expect(await cli(['balance']), 0);
    expect(out.toString(), contains('Address: ${addr.value}'));
    expect(out.toString(), contains('Coin:    $gnfpTicker'));
    expect(out.toString(), contains('Balance: ${book.spendable}'));

    out.clear();
    expect(await cli(['history']), 0);
    expect(out.toString(), contains('send'));
    expect(out.toString(), contains(addr.value));

    const peer = 'gnfp1aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    out.clear();
    expect(await cli(['send', '--to', peer, '--amount', '1.25']), 0);
    expect(book.lastSendTo, peer);
    expect(book.lastSendAmount, 1.25);
    expect(out.toString(), contains('to:     $peer'));
    expect(out.toString(), contains('amount: 1.25 $gnfpTicker'));
    expect(err.toString(), isEmpty);
  });
}

class _SilentPool extends GnfpPoolClient {
  _SilentPool() : super(baseUrl: 'http://127.0.0.1:9');
}

class _BookPool extends GnfpPoolClient {
  _BookPool() : super(baseUrl: 'http://127.0.0.1:9');

  String owner = '';
  final int height = 42;
  final double spendable = 10.5;
  String? lastSendTo;
  double? lastSendAmount;

  @override
  Future<Map<String, dynamic>> get(String path) async {
    if (path.contains('/api/tip') || path.contains('/api/network')) {
      return {
        'ticker': gnfpTicker,
        'height': height,
        'tip': height,
        'tipHeight': height,
        'ok': true,
      };
    }
    if (path.contains('/wallet/balance')) {
      return {'ok': true, 'coin': gnfpTicker, 'balance': spendable};
    }
    if (path.contains('/wallet/history')) {
      return {
        'ok': true,
        'txs': [
          {
            'id': 'tx-1',
            'kind': 'send',
            'from': owner,
            'to': 'gnfp1bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            'amount': 1,
            'memo': '',
            'height': height,
          },
        ],
      };
    }
    throw StateError('unexpected $path');
  }

  @override
  Future<Map<String, dynamic>> send({
    required String from,
    required String to,
    required double amount,
    String memo = '',
  }) async {
    lastSendTo = to;
    lastSendAmount = amount;
    return {
      'ok': true,
      'tx': {
        'id': 'cli-send-1',
        'from': from,
        'to': to,
        'amount': amount,
        'kind': 'send',
        'memo': memo,
      },
      'fromBalance': spendable - amount,
      'toBalance': amount,
    };
  }
}
