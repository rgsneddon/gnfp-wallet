import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnfp_wallet/gnfp_macos_install.dart';

void main() {
  test('only advises a macOS .app that is not already in Applications', () {
    expect(
      shouldAdviseMoveToApplications(
        '/Users/amy/Downloads/gnfp_wallet.app/Contents/MacOS/gnfp_wallet',
      ),
      isTrue,
    );
    expect(
      shouldAdviseMoveToApplications(
        '/Volumes/GNFP/gnfp_wallet.app/Contents/MacOS/gnfp_wallet',
      ),
      isTrue,
    );
    expect(
      shouldAdviseMoveToApplications(
        '/Applications/gnfp_wallet.app/Contents/MacOS/gnfp_wallet',
      ),
      isFalse,
    );
    expect(
      shouldAdviseMoveToApplications(
        '/Users/amy/Applications/GNFP Wallet.app/Contents/MacOS/gnfp_wallet',
      ),
      isFalse,
    );
    expect(
      shouldAdviseMoveToApplications('/var/folders/xx/flutter_tester'),
      isFalse,
    );
    expect(
      shouldAdviseMoveToApplications(
        '/var/containers/Bundle/Application/ABC/Runner.app/Runner',
      ),
      isFalse,
    );
  });

  testWidgets('advisory dialog is macOS-only and can be skipped', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MacosApplicationsHint(
          advise: true,
          child: Scaffold(body: Text('shell')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('gnfp-macos-move-apps')), findsOneWidget);
    expect(find.text(macosMoveTitle), findsOneWidget);
    expect(find.textContaining('Applications folder'), findsWidgets);
    await tester.tap(find.byKey(const Key('gnfp-macos-move-later')));
    await tester.pump();
    expect(find.byKey(const Key('gnfp-macos-move-apps')), findsNothing);
  });

  testWidgets('iPhone/iPad do not get the Applications dialog', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MacosApplicationsHint(
          advise: false,
          child: Scaffold(body: Text('ios-shell')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('gnfp-macos-move-apps')), findsNothing);
    expect(find.text(macosMoveTitle), findsNothing);
  });
}
