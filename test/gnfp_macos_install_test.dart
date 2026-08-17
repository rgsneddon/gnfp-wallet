import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnfp_wallet/gnfp_ledger.dart';
import 'package:gnfp_wallet/gnfp_macos_install.dart';
import 'package:gnfp_wallet/screens/mine_screen.dart';

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

  test('crash-log /var/folders copy is ephemeral and must not mine', () {
    const crash =
        '/private/var/folders/xx/yyyy/T/AppTranslocation/UUID/d/gnfp_wallet.app/Contents/MacOS/gnfp_wallet';
    expect(isEphemeralMacosLaunchPath(crash), isTrue);
    expect(shouldBlockMiningOnLaunchPath(crash), isTrue);
    expect(shouldAdviseMoveToApplications(crash), isTrue);
    expect(isInstalledInApplications(crash), isFalse);
    expect(
      macosAppBundlePath(crash),
      '/private/var/folders/xx/yyyy/T/AppTranslocation/UUID/d/gnfp_wallet.app',
    );
  });

  test('DMG volume is ephemeral until dragged into Applications', () {
    const dmg =
        '/Volumes/GNFP Wallet/GNFP Wallet.app/Contents/MacOS/gnfp_wallet';
    expect(isEphemeralMacosLaunchPath(dmg), isTrue);
    expect(shouldBlockMiningOnLaunchPath(dmg), isTrue);
    expect(
      isEphemeralMacosLaunchPath(
        '/Applications/GNFP Wallet.app/Contents/MacOS/gnfp_wallet',
      ),
      isFalse,
    );
    expect(
      shouldBlockMiningOnLaunchPath(
        '/Applications/GNFP Wallet.app/Contents/MacOS/gnfp_wallet',
      ),
      isFalse,
    );
  });

  test('flutter tester and iOS bundles do not look ephemeral', () {
    expect(isEphemeralMacosLaunchPath('/var/folders/xx/flutter_tester'), isFalse);
    expect(shouldBlockMiningOnLaunchPath('/var/folders/xx/flutter_tester'), isFalse);
    expect(
      isEphemeralMacosLaunchPath(
        '/var/containers/Bundle/Application/ABC/Runner.app/Runner',
      ),
      isFalse,
    );
  });

  test('Downloads .app on a real disk advises but is not a temp vnode', () {
    const downloads =
        '/Users/amy/Downloads/gnfp_wallet.app/Contents/MacOS/gnfp_wallet';
    expect(shouldAdviseMoveToApplications(downloads), isTrue);
    expect(isEphemeralMacosLaunchPath(downloads), isFalse);
    expect(shouldBlockMiningOnLaunchPath(downloads), isFalse);
  });

  test('install destinations prefer GNFP Wallet.app in Applications', () {
    final dests = macosInstallDestinationPaths(home: '/Users/amy');
    expect(dests.first, '/Applications/GNFP Wallet.app');
    expect(dests, contains('/Users/amy/Applications/GNFP Wallet.app'));
  });

  test('installBundleToApplications copies with ditto and strips quarantine', () async {
    final ran = <List<String>>[];
    final dest = await installBundleToApplications(
      resolvedExecutable:
          '/Users/amy/Downloads/gnfp_wallet.app/Contents/MacOS/gnfp_wallet',
      home: '/Users/amy',
      run: (exe, args) async {
        ran.add([exe, ...args]);
        return ProcessResult(0, 0, '', '');
      },
    );
    expect(dest, '/Applications/GNFP Wallet.app');
    expect(ran.any((c) => c[0] == 'ditto'), isTrue);
    expect(
      ran.any((c) => c.contains('com.apple.quarantine')),
      isTrue,
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
    expect(find.byKey(const Key('gnfp-macos-drag-app')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-macos-drag-apps-folder')), findsOneWidget);
    expect(find.text('Applications'), findsWidgets);
    expect(find.textContaining('Applications folder'), findsWidgets);
    await tester.tap(find.byKey(const Key('gnfp-macos-move-later')));
    await tester.pump();
    expect(find.byKey(const Key('gnfp-macos-move-apps')), findsNothing);
  });

  testWidgets('ephemeral launch cannot dismiss the drag-to-Applications window', (
    tester,
  ) async {
    var opened = false;
    var installed = false;
    var exited = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MacosApplicationsHint(
          advise: true,
          requiredMove: true,
          launchExecutable:
              '/private/var/folders/xx/yyyy/T/AppTranslocation/d/gnfp_wallet.app/Contents/MacOS/gnfp_wallet',
          openInstallWindow: () async {
            opened = true;
          },
          installAndRelaunch: () async {
            installed = true;
            return '/Applications/GNFP Wallet.app';
          },
          exitAfterInstall: () => exited = true,
          child: const Scaffold(body: Text('shell')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('gnfp-macos-move-apps')), findsOneWidget);
    expect(find.byKey(const Key('gnfp-macos-move-later')), findsNothing);
    expect(find.textContaining('temporary disk'), findsOneWidget);
    await tester.tap(find.byKey(const Key('gnfp-macos-move-show')));
    await tester.pump();
    expect(opened, isTrue);
    await tester.tap(find.byKey(const Key('gnfp-macos-install-relaunch')));
    await tester.pump();
    expect(installed, isTrue);
    expect(exited, isTrue);
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

  testWidgets('Mine tab will not start hashing on an ephemeral launch', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final addr = GnfpLedger().createAddress(seed: 'mine-block');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MineScreen(address: addr, allowMining: false)),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('gnfp-mine-blocked')), findsOneWidget);
    expect(find.textContaining('Applications'), findsWidgets);
    final start = tester.widget<FilledButton>(find.byKey(const Key('gnfp-mine-start')));
    expect(start.onPressed, isNull);
  });
}
