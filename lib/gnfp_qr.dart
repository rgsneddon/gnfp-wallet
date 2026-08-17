/// QR surface for a GNFP receive address (payload from [qrPayload]).
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'gnfp_ledger.dart';
import 'gnfp_theme.dart';

class GnfpQr extends StatelessWidget {
  const GnfpQr({super.key, required this.address});

  final GnfpAddress address;

  @override
  Widget build(BuildContext context) {
    final payload = qrPayload(address);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomPaint(
          key: const Key('gnfp-qr'),
          size: const Size(168, 168),
          painter: _GnfpQrPainter(payload),
        ),
        const SizedBox(height: 6),
        Text(
          String.fromCharCodes(payload),
          key: const Key('gnfp-qr-payload'),
          style: const TextStyle(color: GnfpTheme.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _GnfpQrPainter extends CustomPainter {
  _GnfpQrPainter(this.payload);
  final Uint8List payload;

  @override
  void paint(Canvas canvas, Size size) {
    const modules = 21;
    final cell = size.width / modules;
    final bg = Paint()..color = const Color(0xFF000000);
    final fg = Paint()..color = const Color(0xFF00E5FF);
    canvas.drawRect(Offset.zero & size, bg);
    for (var y = 0; y < modules; y++) {
      for (var x = 0; x < modules; x++) {
        final i = (y * modules + x) % payload.length;
        final on = ((payload[i] + x * 3 + y * 5) & 1) == 1 ||
            _finder(x, y, modules);
        if (on) {
          canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), fg);
        }
      }
    }
  }

  bool _finder(int x, int y, int n) {
    bool box(int ox, int oy) {
      final dx = (x - ox).abs();
      final dy = (y - oy).abs();
      return dx <= 3 && dy <= 3 && (dx == 3 || dy == 3 || (dx <= 1 && dy <= 1));
    }

    return box(3, 3) || box(n - 4, 3) || box(3, n - 4);
  }

  @override
  bool shouldRepaint(covariant _GnfpQrPainter old) => old.payload != payload;
}
