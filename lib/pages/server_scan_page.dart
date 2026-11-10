import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../sync_qr.dart';
import '../theme.dart';
import '../l10n/l10n.dart';

/// 扫描同步电脑二维码，返回 [SyncEndpoint]。
class ServerScanPage extends StatefulWidget {
  const ServerScanPage({super.key});

  @override
  State<ServerScanPage> createState() => _ServerScanPageState();
}

class _ServerScanPageState extends State<ServerScanPage> {
  final controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [BarcodeFormat.qrCode],
  );
  var handled = false;
  String? hint;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (handled) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue ?? b.displayValue ?? '')
        .firstWhere((s) => s.trim().isNotEmpty, orElse: () => '');
    if (raw.isEmpty) return;

    final endpoint = SyncEndpoint.tryParse(raw);
    if (endpoint == null) {
      if (hint != raw) {
        setState(() => hint = context.l10n.notSyncQr);
      }
      return;
    }

    handled = true;
    await controller.stop();
    if (!mounted) return;
    Navigator.of(context).pop(endpoint);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(context.l10n.scanSyncTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.toggleFlash,
            onPressed: () => controller.toggleTorch(),
            icon: const Icon(Icons.flash_on),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    context.l10n.cameraError(error.errorCode.name),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, height: 1.5),
                  ),
                ),
              );
            },
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: _ScanFramePainter(),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    hint ?? context.l10n.aimSyncQr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: hint == null ? Colors.white : const Color(0xFFFFC9D6),
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final hole = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: size.width * 0.68,
      height: size.width * 0.68,
    );
    final overlay = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(20)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(overlay, Paint()..color = const Color(0x99000000));

    final border = Paint()
      ..color = CamiColors.rose
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(RRect.fromRectAndRadius(hole, const Radius.circular(20)), border);

    const arm = 22.0;
    final corner = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    void cornerAt(Offset o, double dx, double dy) {
      canvas.drawLine(o, o.translate(dx * arm, 0), corner);
      canvas.drawLine(o, o.translate(0, dy * arm), corner);
    }

    cornerAt(hole.topLeft, 1, 1);
    cornerAt(hole.topRight, -1, 1);
    cornerAt(hole.bottomLeft, 1, -1);
    cornerAt(hole.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
