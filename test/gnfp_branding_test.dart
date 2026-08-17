import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnfp_wallet/gnfp_ledger.dart';
import 'package:gnfp_wallet/gnfp_session.dart';
import 'package:gnfp_wallet/gnfp_update.dart';
import 'package:gnfp_wallet/main.dart';

void main() {
  test('shipped logo and macOS app icon are PNG, not the old JPEG diamond', () {
    final logo = File('assets/logo.png');
    final icon = File('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png');
    expect(logo.existsSync(), isTrue);
    expect(icon.existsSync(), isTrue);
    final logoBytes = logo.readAsBytesSync();
    final iconBytes = icon.readAsBytesSync();
    const png = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
    expect(logoBytes.sublist(0, 8), png);
    expect(iconBytes.sublist(0, 8), png);
    expect(logoBytes[0], isNot(0xff));
    expect(logoBytes.length, greaterThan(100000));
    expect(iconBytes.length, greaterThan(100000));
    const oldJpegSha1 = 'bae37650e992c59cdd4b59031b34d86012356589';
    expect(logoBytes.length.toRadixString(16), isNot(oldJpegSha1));
  });

  testWidgets('shell AppBar loads the mediakit logo asset', (tester) async {
    final store = File('${Directory.systemTemp.path}/gnfp-brand-session.json');
    if (store.existsSync()) store.deleteSync();
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      GnfpWalletApp(
        ledger: GnfpLedger(),
        session: GnfpSession(store: store),
        updateCheck: GnfpUpdateCheck(fetchJson: (_) async => null),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('gnfp-logo')), findsOneWidget);
    final image = tester.widget<Image>(find.byKey(const Key('gnfp-logo')));
    expect(image.image, isA<AssetImage>());
    expect((image.image as AssetImage).assetName, 'assets/logo.png');
  });
}
