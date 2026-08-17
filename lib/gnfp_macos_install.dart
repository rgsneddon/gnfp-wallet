/// macOS-only “put this .app in Applications” advice.
/// iPhone/iPad install the IPA into the system app space — there is no
/// Applications folder drag-install, so this never runs on iOS.
library;

import 'dart:io';

import 'package:flutter/material.dart';

const macosMoveTitle = 'Move to Applications';
const macosMoveBody =
    'GNFP Wallet works best from the Applications folder. '
    'Drag the app there from Downloads (or the zip) so it opens and updates cleanly.';
const macosMoveShowFolder = 'Show Applications folder';
const macosMoveNotNow = 'Not now';

/// True only for a real macOS .app that is not already under Applications.
bool shouldAdviseMoveToApplications(String resolvedExecutable) {
  final path = resolvedExecutable.replaceAll('\\', '/');
  final marker = '.app/contents/macos/';
  final idx = path.toLowerCase().indexOf(marker);
  if (idx < 0) return false;
  final bundleDir = path.substring(0, idx + 4);
  return !bundleDir.contains('/Applications/');
}

class MacosApplicationsHint extends StatefulWidget {
  const MacosApplicationsHint({
    super.key,
    required this.child,
    this.advise,
    this.openApplications,
  });

  final Widget child;
  final bool? advise;
  final Future<void> Function()? openApplications;

  @override
  State<MacosApplicationsHint> createState() => _MacosApplicationsHintState();
}

class _MacosApplicationsHintState extends State<MacosApplicationsHint> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAdvise());
  }

  bool get _shouldAdvise {
    if (widget.advise != null) return widget.advise!;
    if (!Platform.isMacOS) return false;
    return shouldAdviseMoveToApplications(Platform.resolvedExecutable);
  }

  Future<void> _maybeAdvise() async {
    if (!mounted || !_shouldAdvise) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          key: const Key('gnfp-macos-move-apps'),
          title: const Text(macosMoveTitle),
          content: const Text(macosMoveBody),
          actions: [
            TextButton(
              key: const Key('gnfp-macos-move-later'),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(macosMoveNotNow),
            ),
            FilledButton(
              key: const Key('gnfp-macos-move-show'),
              onPressed: () async {
                final open = widget.openApplications ?? _openApplicationsFolder;
                await open();
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text(macosMoveShowFolder),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openApplicationsFolder() async {
    if (!Platform.isMacOS) return;
    await Process.run('open', ['/Applications']);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
