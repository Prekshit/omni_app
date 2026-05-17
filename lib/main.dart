import 'dart:ui';
import 'package:flutter/material.dart';

void main() {
  runApp(const OmniApp());
}

class OmniApp extends StatelessWidget {
  const OmniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Omni',
      theme: ThemeData(
        fontFamily: 'Roboto',
      ),
      home: const ScannerScreen(),
    );
  }
}

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  static const Color phonePePurple = Color(0xFF6A1BCE);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [

          /// BACKGROUND IMAGE
          Image.network(
            'https://images.unsplash.com/photo-1506744038136-46273834b3fb',
            fit: BoxFit.cover,
          ),

          /// DARK OVERLAY
          Container(
            color: Colors.black.withOpacity(0.45),
          ),

          /// GLOBAL BLUR
          BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 10,
              sigmaY: 10,
            ),
            child: Container(
              color: Colors.black.withOpacity(0.05),
            ),
          ),

          SafeArea(
            child: Column(
              children: [

                /// TOP BAR
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [

                      const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 28,
                      ),

                      const SizedBox(width: 16),

                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [

                            Text(
                              "Scan any QR",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                              ),
                            ),

                            SizedBox(height: 4),

                            Text(
                              "PhonePe • Google Pay • BHIM • Paytm",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white70,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.question_mark,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 70),

                /// SCANNER AREA
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Stack(
                      children: [

                        /// SEMI TRANSPARENT SCANNER BOX
                        Container(
                          width: 265,
                          height: 265,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius:
                                BorderRadius.circular(28),
                          ),
                        ),

                        /// CORNERS
                        SizedBox(
                          width: 265,
                          height: 265,
                          child: CustomPaint(
                            painter: ScannerCornerPainter(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 55),

                /// BUTTONS
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [

                    scannerButton(
                      icon: Icons.image_outlined,
                      label: "Upload QR",
                    ),

                    const SizedBox(width: 30),

                    scannerButton(
                      icon: Icons.flashlight_on,
                      label: "Torch",
                    ),

                    const SizedBox(width: 30),

                    omniButton(context),
                  ],
                ),

                const Spacer(),

                /// BHIM TEXT
                Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Text(
                    "BHIM | UPI",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.40),
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
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

  Widget scannerButton({
    required IconData icon,
    required String label,
  }) {
    return Column(
      children: [

        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.12),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 32,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget omniButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF1A1A1A),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          builder: (context) {
            return Container(
              padding: const EdgeInsets.all(22),
              height: 340,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [

                  const Text(
                    "Similar Products Found",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 24),

                  productTile(
                    "Nike Air Max 270",
                    "₹4,999",
                    "Seller: Nike Store",
                  ),

                  productTile(
                    "Nike Air Max Alpha",
                    "₹6,499",
                    "Seller: Myntra",
                  ),

                  productTile(
                    "Nike Air Max Pulse",
                    "₹8,999",
                    "Seller: Flipkart",
                  ),
                ],
              ),
            );
          },
        );
      },
      child: Column(
        children: [

          Stack(
            clipBehavior: Clip.none,
            children: [

              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 32,
                ),
              ),

              Positioned(
                top: -8,
                right: -10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: phonePePurple,
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "NEW",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          const Text(
            "Omni",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget productTile(
    String name,
    String price,
    String seller,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [

          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.shopping_bag,
              color: Colors.white,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [

                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  seller,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          Text(
            price,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class ScannerCornerPainter extends CustomPainter {

  @override
  void paint(Canvas canvas, Size size) {

    const double padding = 18;
    const double cornerLength = 32;
    const double radius = 16;
    const double strokeWidth = 4;

    final paint = Paint()
      ..color = const Color(0xFF7B1FFF)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    /// TOP LEFT
    final path1 = Path()
      ..moveTo(padding + radius, padding)
      ..lineTo(padding + cornerLength, padding)
      ..moveTo(padding, padding + radius)
      ..lineTo(padding, padding + cornerLength);

    canvas.drawArc(
      Rect.fromLTWH(
        padding,
        padding,
        radius * 2,
        radius * 2,
      ),
      3.14,
      1.57,
      false,
      paint,
    );

    canvas.drawPath(path1, paint);

    /// TOP RIGHT
    final path2 = Path()
      ..moveTo(size.width - padding - radius, padding)
      ..lineTo(size.width - padding - cornerLength, padding)
      ..moveTo(size.width - padding, padding + radius)
      ..lineTo(size.width - padding, padding + cornerLength);

    canvas.drawArc(
      Rect.fromLTWH(
        size.width - padding - radius * 2,
        padding,
        radius * 2,
        radius * 2,
      ),
      -1.57,
      1.57,
      false,
      paint,
    );

    canvas.drawPath(path2, paint);

    /// BOTTOM LEFT
    final path3 = Path()
      ..moveTo(padding + radius, size.height - padding)
      ..lineTo(padding + cornerLength, size.height - padding)
      ..moveTo(padding, size.height - padding - radius)
      ..lineTo(padding, size.height - padding - cornerLength);

    canvas.drawArc(
      Rect.fromLTWH(
        padding,
        size.height - padding - radius * 2,
        radius * 2,
        radius * 2,
      ),
      1.57,
      1.57,
      false,
      paint,
    );

    canvas.drawPath(path3, paint);

    /// BOTTOM RIGHT
    final path4 = Path()
      ..moveTo(
          size.width - padding - radius,
          size.height - padding)
      ..lineTo(
          size.width - padding - cornerLength,
          size.height - padding)
      ..moveTo(
          size.width - padding,
          size.height - padding - radius)
      ..lineTo(
          size.width - padding,
          size.height - padding - cornerLength);

    canvas.drawArc(
      Rect.fromLTWH(
        size.width - padding - radius * 2,
        size.height - padding - radius * 2,
        radius * 2,
        radius * 2,
      ),
      0,
      1.57,
      false,
      paint,
    );

    canvas.drawPath(path4, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}