import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnfp_wallet/gnfp_in_wallet_miner.dart';
import 'package:gnfp_wallet/gnfp_ledger.dart';
import 'package:gnfp_wallet/gnfp_mine_command.dart';
import 'package:gnfp_wallet/gnfp_mining_dot.dart';
import 'package:gnfp_wallet/gnfp_session.dart';
import 'package:gnfp_wallet/gnfp_theme.dart';
import 'package:gnfp_wallet/gnfp_update.dart';
import 'package:gnfp_wallet/main.dart';

Future<void> _pumpBoot(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('MINE GNFP keeps hashing off the Mine tab and shows a green flashing dot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final server = await tester.runAsync(
      () => ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
    );
    expect(server, isNotNull);
    addTearDown(() async {
      await tester.runAsync(server!.close);
    });
    server!.listen((sock) {
      sock.listen((data) {
        final line = utf8.decode(data).trim();
        if (line.isEmpty) return;
        final msg = jsonDecode(line);
        if (msg is! Map) return;
        if (msg['method'] == 'login') {
          sock.add(
            utf8.encode(
              '${jsonEncode({
                "jsonrpc": "2.0",
                "method": "job",
                "jobId": "j-persist",
                "id": "j-persist",
                "height": 1,
                "difficulty": 1,
                "input": "aaa",
              })}\n',
            ),
          );
        }
      });
    });

    final miner = InWalletMiner(
      connect: (_, __) => Socket.connect(InternetAddress.loopbackIPv4, server.port),
    );
    addTearDown(() async {
      await tester.runAsync(miner.stop);
    });

    final store = File('${Directory.systemTemp.path}/gnfp-mine-persist-session.json');
    if (store.existsSync()) store.deleteSync();

    await tester.pumpWidget(
      GnfpWalletApp(
        ledger: GnfpLedger(),
        version: '0.0.7',
        session: GnfpSession(store: store),
        updateCheck: GnfpUpdateCheck(fetchJson: (_) async => null),
        miner: miner,
      ),
    );
    await _pumpBoot(tester);

    expect(find.byKey(miningDotKey), findsNothing);
    expect(miner.status.running, isFalse);

    await tester.tap(find.byIcon(Icons.memory));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('gnfp-mine-start')), findsOneWidget);
    expect(find.text('MINE GNFP'), findsOneWidget);

    await tester.tap(find.byKey(const Key('gnfp-mine-start')));
    for (var i = 0; i < 40 && !miner.status.running; i++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
    }
    expect(miner.status.running, isTrue);
    await tester.pump();
    expect(find.text('STOP'), findsOneWidget);
    expect(find.byKey(miningDotKey), findsOneWidget);

    await tester.tap(find.byIcon(Icons.account_balance_wallet));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('gnfp-box-identity')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-mine-start')), findsNothing);
    expect(miner.status.running, isTrue);
    expect(find.byKey(miningDotKey), findsOneWidget);
    final dot = tester.widget<Container>(find.byKey(miningDotKey));
    expect(dot.decoration, isA<BoxDecoration>());
    expect((dot.decoration! as BoxDecoration).color, GnfpTheme.neonLime);

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(miningDotKey), findsOneWidget);
    expect(miner.status.running, isTrue);

    await tester.tap(find.byIcon(Icons.explore));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('gnfp-owner-ledger')), findsOneWidget);
    expect(miner.status.running, isTrue);
    expect(find.byKey(miningDotKey), findsOneWidget);

    await tester.tap(find.byIcon(Icons.memory));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('STOP'), findsOneWidget);
    await tester.tap(find.byKey(const Key('gnfp-mine-start')));
    for (var i = 0; i < 40 && miner.status.running; i++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
    }
    expect(miner.status.running, isFalse);
    await tester.pump();
    expect(find.text('MINE GNFP'), findsOneWidget);
    expect(find.byKey(miningDotKey), findsNothing);

    await tester.tap(find.byIcon(Icons.account_balance_wallet));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(miningDotKey), findsNothing);
    expect(miner.status.running, isFalse);
  });

  testWidgets('Mine tab picks threads, another gnfp1, and a functioning pool', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final store = File('${Directory.systemTemp.path}/gnfp-mine-controls-session.json');
    if (store.existsSync()) store.deleteSync();
    await tester.pumpWidget(
      GnfpWalletApp(
        ledger: GnfpLedger(),
        version: '0.0.7',
        session: GnfpSession(store: store),
        updateCheck: GnfpUpdateCheck(fetchJson: (_) async => null),
        processors: 4,
      ),
    );
    await _pumpBoot(tester);
    await tester.tap(find.byIcon(Icons.memory));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('gnfp-mine-pool')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-mine-pool-host')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-mine-payout')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-mine-threads')), findsOneWidget);

    const other = 'gnfp1c91376d3ad811073a70b416539a962c9090bc67e';
    await tester.enterText(find.byKey(const Key('gnfp-mine-payout')), other);
    await tester.pump();

    await tester.tap(find.byKey(const Key('gnfp-mine-threads')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('3'), findsWidgets);
    expect(find.text('4'), findsNothing);
    await tester.tap(find.text('3').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byKey(const Key('gnfp-mine-pool')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.textContaining('Helsinki front').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final cmd =
        tester.widget<SelectableText>(find.byKey(const Key('gnfp-miner-cmd'))).data ?? '';
    expect(cmd, contains('--user $other.worker'));
    expect(cmd, contains('--threads 3'));
    expect(cmd, contains('--pool hel.restoreprivacy.online:1474'));
    expect(cmd.contains('--notls'), isFalse);
    expect(gnfpMinePools.map((p) => p.hostPort), contains('hel.restoreprivacy.online:1474'));
  });

  testWidgets('owned miner dispose stops hashing and does not log in again', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final server = await tester.runAsync(
      () => ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
    );
    expect(server, isNotNull);
    addTearDown(() async {
      await tester.runAsync(server!.close);
    });
    var logins = 0;
    server!.listen((sock) {
      sock.listen((data) {
        for (final line in utf8.decode(data).split('\n')) {
          if (line.trim().isEmpty) continue;
          final msg = jsonDecode(line);
          if (msg is! Map) continue;
          if (msg['method'] == 'login') {
            logins += 1;
            sock.add(
              utf8.encode(
                '${jsonEncode({
                  "jsonrpc": "2.0",
                  "method": "job",
                  "jobId": "j-dispose",
                  "id": "j-dispose",
                  "height": 1,
                  "difficulty": 1,
                  "input": "aaa",
                })}\n',
              ),
            );
          }
        }
      });
    });

    final store = File('${Directory.systemTemp.path}/gnfp-mine-dispose-session.json');
    if (store.existsSync()) store.deleteSync();

    await tester.pumpWidget(
      GnfpWalletApp(
        ledger: GnfpLedger(),
        version: '0.0.7',
        session: GnfpSession(store: store),
        updateCheck: GnfpUpdateCheck(fetchJson: (_) async => null),
        processors: 4,
      ),
    );
    await _pumpBoot(tester);
    await tester.tap(find.byIcon(Icons.memory));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.enterText(
      find.byKey(const Key('gnfp-mine-pool-host')),
      '127.0.0.1:${server.port}',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('gnfp-mine-start')));
    for (var i = 0; i < 40 && logins < 1; i++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
    }
    expect(logins, greaterThanOrEqualTo(1));
    expect(find.text('STOP'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final after = logins;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    expect(logins, after);
  });
}
