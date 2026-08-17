/// macOS install: drag the .app into Applications, and never keep mining
/// from a temp / translocated / disk-image copy.
///
/// The crash (SIGBUS, “backing vnode was force unmounted”) happens when
/// Gatekeeper runs a quarantined zip from `/private/var/folders/…` or the
/// user launches off the DMG. macOS later unmounts that volume and the
/// next LaunchServices callback dies inside the mapped Flutter binary.
/// iPhone/iPad install the IPA into the system app space — no Applications
/// drag — so this never runs on iOS.
library;

import 'dart:io';

import 'package:flutter/material.dart';

const macosMoveTitle = 'Install GNFP Wallet';
const macosMoveBody =
    'Drag GNFP Wallet onto the Applications folder. '
    'Leaving it in Downloads, a zip, or the disk image lets macOS unmount '
    'that copy while you mine — the wallet then crashes.';
const macosMoveRequiredBody =
    'This copy is running from a temporary disk. '
    'Drag GNFP Wallet onto Applications (or install and relaunch) before mining.';
const macosOpenInstallWindow = 'Open install window';
const macosInstallRelaunch = 'Install and relaunch';
const macosMoveNotNow = 'Not now';
const macosMoveShowFolder = macosOpenInstallWindow;
const macosAppDisplayName = 'GNFP Wallet';
const macosInstalledBundleName = 'GNFP Wallet.app';
const macosProductBundleName = 'gnfp_wallet.app';

const _appMarker = '.app/contents/macos/';

String _unix(String path) => path.replaceAll('\\', '/');

/// Directory of the `.app` bundle, or null if [resolvedExecutable] is not one.
String? macosAppBundlePath(String resolvedExecutable) {
  final path = _unix(resolvedExecutable);
  final idx = path.toLowerCase().indexOf(_appMarker);
  if (idx < 0) return null;
  return path.substring(0, idx + 4);
}

bool isMacosAppExecutable(String resolvedExecutable) =>
    macosAppBundlePath(resolvedExecutable) != null;

/// True when the bundle already lives in Applications or ~/Applications.
bool isInstalledInApplications(String resolvedExecutable) {
  final bundle = macosAppBundlePath(resolvedExecutable);
  if (bundle == null) return false;
  return bundle.contains('/Applications/');
}

/// True for App Translocation, /var/folders temp copies, and DMG volumes.
/// Those are the paths whose backing vnode macOS force-unmounts.
bool isEphemeralMacosLaunchPath(String resolvedExecutable) {
  final bundle = macosAppBundlePath(resolvedExecutable);
  if (bundle == null) return false;
  if (isInstalledInApplications(bundle)) return false;
  final lower = bundle.toLowerCase();
  if (lower.contains('/apptranslocation/')) return true;
  if (lower.contains('/var/folders/')) return true;
  if (lower.contains('/temporaryitems/')) return true;
  if (lower.contains('/volumes/')) return true;
  return false;
}

/// True only for a real macOS .app that is not already under Applications.
bool shouldAdviseMoveToApplications(String resolvedExecutable) {
  return isMacosAppExecutable(resolvedExecutable) &&
      !isInstalledInApplications(resolvedExecutable);
}

/// Mining is a long-lived workload. Do not start it on a doomed volume.
bool shouldBlockMiningOnLaunchPath(String resolvedExecutable) =>
    isEphemeralMacosLaunchPath(resolvedExecutable);

List<String> macosInstallDestinationPaths({String? home}) {
  final h = (home ?? Platform.environment['HOME'] ?? '').trim();
  final trimmed = h.endsWith('/') ? h.substring(0, h.length - 1) : h;
  return [
    '/Applications/$macosInstalledBundleName',
    if (trimmed.isNotEmpty) '$trimmed/Applications/$macosInstalledBundleName',
    '/Applications/$macosProductBundleName',
    if (trimmed.isNotEmpty) '$trimmed/Applications/$macosProductBundleName',
  ];
}

typedef MacosCommandRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// Copy the running .app onto a real Applications folder. Returns the dest.
Future<String?> installBundleToApplications({
  required String resolvedExecutable,
  MacosCommandRunner? run,
  String? home,
}) async {
  final bundle = macosAppBundlePath(resolvedExecutable);
  if (bundle == null) return null;
  final runner = run ?? Process.run;
  for (final dest in macosInstallDestinationPaths(home: home)) {
    final parent = dest.substring(0, dest.lastIndexOf('/'));
    final mkdir = await runner('mkdir', ['-p', parent]);
    if (mkdir.exitCode != 0) continue;
    await runner('rm', ['-rf', dest]);
    final copied = await runner('ditto', [bundle, dest]);
    if (copied.exitCode != 0) continue;
    await runner('/usr/bin/xattr', ['-dr', 'com.apple.quarantine', dest]);
    return dest;
  }
  return null;
}

Future<void> relaunchInstalledApp(
  String dest, {
  MacosCommandRunner? run,
}) async {
  final runner = run ?? Process.run;
  await runner('open', ['-n', dest]);
}

Future<void> openMacosInstallWindow(
  String resolvedExecutable, {
  MacosCommandRunner? run,
}) async {
  final runner = run ?? Process.run;
  final bundle = macosAppBundlePath(resolvedExecutable);
  if (bundle != null) {
    await runner('open', ['-R', bundle]);
  }
  await runner('open', ['/Applications']);
}

class MacosApplicationsHint extends StatefulWidget {
  const MacosApplicationsHint({
    super.key,
    required this.child,
    this.advise,
    this.requiredMove,
    this.launchExecutable,
    this.openApplications,
    this.openInstallWindow,
    this.installAndRelaunch,
    this.exitAfterInstall,
  });

  final Widget child;
  final bool? advise;
  final bool? requiredMove;
  final String? launchExecutable;
  final Future<void> Function()? openApplications;
  final Future<void> Function()? openInstallWindow;
  final Future<String?> Function()? installAndRelaunch;
  final void Function()? exitAfterInstall;

  @override
  State<MacosApplicationsHint> createState() => _MacosApplicationsHintState();
}

class _MacosApplicationsHintState extends State<MacosApplicationsHint> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAdvise());
  }

  String get _launchPath {
    if (widget.launchExecutable != null) return widget.launchExecutable!;
    if (!Platform.isMacOS) return '';
    return Platform.resolvedExecutable;
  }

  bool get _required {
    if (widget.requiredMove != null) return widget.requiredMove!;
    return isEphemeralMacosLaunchPath(_launchPath);
  }

  bool get _shouldAdvise {
    if (widget.advise != null) return widget.advise! || _required;
    if (!Platform.isMacOS) return false;
    return shouldAdviseMoveToApplications(_launchPath) || _required;
  }

  Future<void> _maybeAdvise() async {
    if (!mounted || !_shouldAdvise) return;
    final required = _required;
    await showDialog<void>(
      context: context,
      barrierDismissible: !required,
      builder: (ctx) {
        return Dialog(
          key: const Key('gnfp-macos-move-apps'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    macosMoveTitle,
                    style: Theme.of(ctx).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const _MacosDragInstallRow(),
                  const SizedBox(height: 16),
                  Text(
                    required ? macosMoveRequiredBody : macosMoveBody,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!required)
                        TextButton(
                          key: const Key('gnfp-macos-move-later'),
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text(macosMoveNotNow),
                        ),
                      TextButton(
                        key: const Key('gnfp-macos-move-show'),
                        onPressed: () async {
                          final open = widget.openInstallWindow ??
                              widget.openApplications ??
                              () => openMacosInstallWindow(_launchPath);
                          await open();
                        },
                        child: const Text(macosOpenInstallWindow),
                      ),
                      FilledButton(
                        key: const Key('gnfp-macos-install-relaunch'),
                        onPressed: () async {
                          final injected = widget.installAndRelaunch;
                          final dest = injected != null
                              ? await injected()
                              : await installBundleToApplications(
                                  resolvedExecutable: _launchPath,
                                );
                          if (dest == null || dest.isEmpty) return;
                          if (injected == null) {
                            await relaunchInstalledApp(dest);
                          }
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          (widget.exitAfterInstall ?? _exitProcess)();
                        },
                        child: const Text(macosInstallRelaunch),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _exitProcess() {
    if (!Platform.isMacOS) return;
    exit(0);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _MacosDragInstallRow extends StatelessWidget {
  const _MacosDragInstallRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _MacosDragTile(
          tileKey: Key('gnfp-macos-drag-app'),
          asset: 'assets/logo.png',
          label: macosAppDisplayName,
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Icon(Icons.arrow_forward, size: 36),
        ),
        _MacosDragTile(
          tileKey: Key('gnfp-macos-drag-apps-folder'),
          icon: Icons.folder,
          label: 'Applications',
        ),
      ],
    );
  }
}

class _MacosDragTile extends StatelessWidget {
  const _MacosDragTile({
    required this.tileKey,
    required this.label,
    this.asset,
    this.icon,
  });

  final Key tileKey;
  final String label;
  final String? asset;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: tileKey,
      width: 120,
      child: Column(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: asset != null
                ? Image.asset(asset!, fit: BoxFit.contain)
                : Icon(icon, size: 64),
          ),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
