import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnfp_wallet/gnfp_ledger.dart';
import 'package:gnfp_wallet/gnfp_seed.dart';
import 'package:gnfp_wallet/screens/backup_screen.dart';

void main() {
  test('current 12-word phrase restores the same gnfp1', () {
    final ledger = GnfpLedger();
    const seed = 'keep-me';
    final addr = ledger.createAddress(seed: seed);
    final phrase = backupPhraseFor(addr, seed: seed);
    expect(gnfpPhraseWords(phrase), hasLength(12));
    expect(restoreFromPhrase(phrase, ledger, addr, seed).value, addr.value);
  });

  test('wrong 12 words mint a different empty gnfp1', () {
    final ledger = GnfpLedger();
    const seed = 'keep-me';
    final addr = ledger.createAddress(seed: seed);
    ledger.rememberSpendable(addr, 9);
    const wrong = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    final next = restoreFromPhrase(wrong, ledger, addr, seed);
    expect(next.value, isNot(addr.value));
    expect(ledger.balance(next), 0);
  });

  testWidgets('backup shows 12 boxes, copy/paste, yellow warning', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final ledger = GnfpLedger();
    const seed = 'box-seed';
    final addr = ledger.createAddress(seed: seed);
    var clip = backupPhraseFor(addr, seed: seed);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BackupScreen(
            address: addr,
            ledger: ledger,
            seed: seed,
            clipboard: ClipboardDelegate(
              read: () async => clip,
              write: (t) async {
                clip = t;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('gnfp-seed-box-0')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-seed-box-11')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-copy-phrase')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-paste-phrase')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-wrong-phrase-warning')), findsOneWidget);
    expect(find.textContaining('wrong 12-word phrase'), findsOneWidget);
    final yellow = tester.widget<Text>(find.textContaining('wrong 12-word phrase'));
    expect(yellow.style?.color, const Color(0xFFFFE600));
    await tester.tap(find.byKey(const Key('gnfp-copy-phrase')));
    await tester.pump();
    expect(clip.split(' '), hasLength(12));
    await tester.enterText(find.byKey(const Key('gnfp-seed-box-0')), 'zzzz');
    await tester.pump();
    await tester.tap(find.byKey(const Key('gnfp-paste-phrase')));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(const Key('gnfp-seed-box-0'))).controller?.text,
      gnfpPhraseWords(clip).first,
    );
    await tester.tap(find.byKey(const Key('gnfp-restore')));
    await tester.pump();
    expect(find.textContaining('restored ${addr.value}'), findsOneWidget);
  });
}
