import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  late MobileScannerController controller;
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;
  bool _isProcessing = false;
  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: [
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.ean8,
        BarcodeFormat.ean13,
        BarcodeFormat.code128,
        BarcodeFormat.qrCode,
      ],
    );

    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    _laserController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? rawValue = barcodes.first.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        setState(() {
          _isProcessing = true;
        });

        // Haptic feedback
        HapticFeedback.mediumImpact();

        // Stop camera scanning instantly to freeze
        controller.stop();

        // Return barcode back to parent screen
        Navigator.of(context).pop(rawValue);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandPlum = Color(0xFF360816);
    const Color fetchPurple = Color(0xFF6A1BCE);
    const Color fetchGold = Color(0xFFFFB300);

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth * 0.82;
          final height = 180.0;
          final top = (constraints.maxHeight - height) / 2 - 50;
          final left = (constraints.maxWidth - width) / 2;
          final scanWindow = Rect.fromLTWH(left, top, width, height);

          return Stack(
            fit: StackFit.expand,
            children: [
              // Layer 1: Fullscreen Mobile Scanner Viewport
              MobileScanner(
                controller: controller,
                onDetect: _onDetect,
                scanWindow: scanWindow,
              ),

              // Layer 2: Transparent Deep Plum Overlay with Target Window Clip
              ClipPath(
                clipper: InvertedClipper(
                  scanWindow: scanWindow,
                  borderRadius: 16,
                ),
                child: Container(
                  color: brandPlum.withOpacity(0.85),
                ),
              ),

              // Layer 3: Interactive Viewport Borders (Subtle Glowing Corners)
              Positioned.fromRect(
                rect: scanWindow,
                child: CustomPaint(
                  painter: ScannerFramePainter(
                    borderColor: fetchGold,
                    borderRadius: 16,
                    borderWidth: 3,
                  ),
                ),
              ),

              // Layer 4: Animated Vertical Laser Line (Fetch Purple Accent)
              AnimatedBuilder(
                animation: _laserAnimation,
                builder: (context, child) {
                  final lineY = scanWindow.top + (scanWindow.height * _laserAnimation.value);
                  return Positioned(
                    top: lineY - 1,
                    left: scanWindow.left + 15,
                    width: scanWindow.width - 30,
                    height: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: fetchPurple.withOpacity(0.8),
                            blurRadius: 10,
                            spreadRadius: 3,
                          ),
                          BoxShadow(
                            color: fetchGold.withOpacity(0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                        gradient: LinearGradient(
                          colors: [
                            fetchPurple.withOpacity(0.1),
                            fetchPurple,
                            fetchPurple,
                            fetchPurple.withOpacity(0.1),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Layer 5: Fullscreen Controls (Header Bar & Instruction Text)
              SafeArea(
                child: Column(
                  children: [
                    // Header Bar (Floating widgets)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Back Exit button
                          _circleButton(
                            icon: Icons.close_rounded,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          // Title
                          const Text(
                            "Fetch Barcode Search",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          // Flash toggle button
                          _circleButton(
                            icon: _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            iconColor: _isFlashOn ? fetchGold : Colors.white,
                            onTap: () async {
                              await controller.toggleTorch();
                              setState(() {
                                _isFlashOn = !_isFlashOn;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    
                    // Loader Indicator when processing the scan
                    if (_isProcessing)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: brandPlum.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: fetchPurple.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(fetchPurple),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              "Scanning barcode...",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      // Standard Instruction Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.center_focus_weak_rounded, color: fetchGold, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              "Align barcode inside frame",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 70),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}

// ── Custom Painter for Target Frame Corners ───────────────────────────────────

class ScannerFramePainter extends CustomPainter {
  const ScannerFramePainter({
    required this.borderColor,
    required this.borderRadius,
    required this.borderWidth,
  });

  final Color borderColor;
  final double borderRadius;
  final double borderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final length = size.width * 0.12;

    // Top Left Corner
    canvas.drawPath(
      Path()
        ..moveTo(0, length)
        ..lineTo(0, borderRadius)
        ..arcToPoint(
          Offset(borderRadius, 0),
          radius: Radius.circular(borderRadius),
          clockwise: true,
        )
        ..lineTo(length, 0),
      paint,
    );

    // Top Right Corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width - length, 0)
        ..lineTo(size.width - borderRadius, 0)
        ..arcToPoint(
          Offset(size.width, borderRadius),
          radius: Radius.circular(borderRadius),
          clockwise: true,
        )
        ..lineTo(size.width, length),
      paint,
    );

    // Bottom Right Corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width, size.height - length)
        ..lineTo(size.width, size.height - borderRadius)
        ..arcToPoint(
          Offset(size.width - borderRadius, size.height),
          radius: Radius.circular(borderRadius),
          clockwise: true,
        )
        ..lineTo(size.width - length, size.height),
      paint,
    );

    // Bottom Left Corner
    canvas.drawPath(
      Path()
        ..moveTo(length, size.height)
        ..lineTo(borderRadius, size.height)
        ..arcToPoint(
          Offset(0, size.height - borderRadius),
          radius: Radius.circular(borderRadius),
          clockwise: true,
        )
        ..lineTo(0, size.height - length),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Inverted Clipper to punch a transparent hole in a dark overlay ─────────────

class InvertedClipper extends CustomClipper<Path> {
  const InvertedClipper({
    required this.scanWindow,
    required this.borderRadius,
  });

  final Rect scanWindow;
  final double borderRadius;

  @override
  Path getClip(Size size) {
    return Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          scanWindow,
          Radius.circular(borderRadius),
        ),
      )
      ..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(covariant InvertedClipper oldClipper) {
    return oldClipper.scanWindow != scanWindow ||
        oldClipper.borderRadius != borderRadius;
  }
}
