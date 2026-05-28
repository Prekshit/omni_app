import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as math;


List<CameraDescription> cameras = [];

const String omniSearchEndpoint = String.fromEnvironment(
  'OMNI_BACKEND_URL',
  defaultValue: 'http://10.0.2.2:3000/api/visual-search',
);

const MethodChannel _nativeChannel = MethodChannel('com.example.omni_app/native');

bool isProductPhonePeEnabled(OmniProduct product, List<OmniProduct> categoryProducts) {
  if (product.categoryId == 'other') return false;
  final index = categoryProducts.indexOf(product);
  
  final int seed = product.categoryId.hashCode;
  
  if (product.categoryId == 'indian_ecommerce') {
    if (index < 0 || index >= 5) return false;
    final int count = 2 + (seed.abs() % 4); // Min 2, Max 5
    return index < count;
  } else {
    if (index < 0 || index >= 3) return false;
    final int count = 1 + (seed.abs() % 3); // Min 1, Max 3
    return index < count;
  }
}



Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  try {
    cameras = await availableCameras();
  } catch (_) {
    cameras = [];
  }

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

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() =>
      _ScannerScreenState();
}

class _ScannerScreenState
    extends State<ScannerScreen> {

  CameraController? controller;
  String? cameraError;
  final GlobalKey scannerKey = GlobalKey();
  Rect? scannerRect;

  static const Color phonePePurple =
      Color(0xFF6A1BCE);

  @override
  void initState() {
    super.initState();

    if (cameras.isEmpty) {
      cameraError = 'No camera found on this device.';
      return;
    }

    final cameraController = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    controller = cameraController;

    cameraController.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    }).catchError((_) {
      if (!mounted) return;
      setState(() {
        cameraError = 'Unable to open the camera.';
      });
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void updateScannerRect() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final renderBox =
          scannerKey.currentContext?.findRenderObject() as RenderBox?;

      if (renderBox == null || !renderBox.hasSize || !mounted) {
        return;
      }

      final topLeft = renderBox.localToGlobal(Offset.zero);
      final nextRect = topLeft & renderBox.size;

      if (scannerRect == nextRect) {
        return;
      }

      setState(() {
        scannerRect = nextRect;
      });
    });
  }

  @override
  Widget build(BuildContext context) {

    updateScannerRect();

    final cameraController = controller;

    if (cameraError != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  const Icon(
                    Icons.videocam_off_outlined,
                    color: Colors.white70,
                    size: 56,
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Camera unavailable',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    cameraError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (cameraController == null ||
        !cameraController.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [

          /// LIVE CAMERA PREVIEW
          CameraPreview(cameraController),

          /// BLUR ONLY OUTSIDE THE SCANNER AREA
          if (scannerRect != null)
            ClipPath(
              clipper: ScannerBlurClipper(scannerRect!),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 10,
                  sigmaY: 10,
                ),
                child: Container(
                  color: Colors.black.withOpacity(0.50),
                ),
              ),
            )
          else
            Container(
              color: Colors.black.withOpacity(0.50),
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
                    key: scannerKey,
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

                    omniButton(context, cameraController),
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

  Widget omniButton(
    BuildContext context,
    CameraController cameraController,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, __, ___) => OmniScannerScreen(
              controller: cameraController,
            ),
          ),
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

}

class OmniProduct {
  const OmniProduct({
    required this.title,
    required this.image,
    required this.price,
    required this.source,
    required this.shoppingLink,
    required this.domain,
    required this.categoryId,
    required this.categoryTitle,
  });

  final String title;
  final String image;
  final String price;
  final String source;
  final String shoppingLink;
  final String domain;
  final String categoryId;
  final String categoryTitle;

  factory OmniProduct.fromJson(Map<String, dynamic> json) {
    return OmniProduct(
      title: json['title']?.toString() ?? 'Untitled product',
      image: json['image']?.toString() ?? '',
      price: json['price']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      shoppingLink: json['shoppingLink']?.toString() ?? '',
      domain: json['domain']?.toString() ?? '',
      categoryId: json['categoryId']?.toString() ?? 'other',
      categoryTitle:
          json['categoryTitle']?.toString() ?? 'Other Matches',
    );
  }

  OmniProduct copyWith({String? price}) {
    return OmniProduct(
      title: title,
      image: image,
      price: price ?? this.price,
      source: source,
      shoppingLink: shoppingLink,
      domain: domain,
      categoryId: categoryId,
      categoryTitle: categoryTitle,
    );
  }
}

class OmniCategory {
  const OmniCategory({
    required this.id,
    required this.title,
    required this.products,
  });

  final String id;
  final String title;
  final List<OmniProduct> products;

  factory OmniCategory.fromJson(Map<String, dynamic> json) {
    final productsJson = json['products'];

    return OmniCategory(
      id: json['id']?.toString() ?? 'other',
      title: json['title']?.toString() ?? 'Other Matches',
      products: productsJson is List
          ? productsJson
              .whereType<Map<String, dynamic>>()
              .map(OmniProduct.fromJson)
              .toList()
          : [],
    );
  }
}

class OmniSearchException implements Exception {
  const OmniSearchException(this.message);

  final String message;

  @override
  String toString() => message;
}

// ════════════════════════════════════════════════════════════════════════════
// CROP FEATURE: scanner mode state machine
// ════════════════════════════════════════════════════════════════════════════
enum _ScannerMode {
  liveCamera,        // Normal live camera preview
  capturedWithSheet, // Photo taken; frozen image in bg, sheet visible
  cropMode,          // Sheet dismissed; crop rect visible on frozen image
}

class OmniScannerScreen extends StatefulWidget {
  const OmniScannerScreen({
    super.key,
    required this.controller,
  });

  final CameraController controller;

  @override
  State<OmniScannerScreen> createState() => _OmniScannerScreenState();
}

class _OmniScannerScreenState extends State<OmniScannerScreen> {
  static const Color scannerDarkPlum = Color(0xFF360816);
  bool isCapturing = false;

  CameraController get controller => widget.controller;

  // ── Crop / sheet state ────────────────────────────────────────────────────
  _ScannerMode _scannerMode = _ScannerMode.liveCamera;
  Uint8List? _capturedImageBytes;  // original photo bytes — kept for re-crops
  ui.Image? _capturedUiImage;      // decoded native image for dart:ui crop ops
  int _cropAttemptCount = 0;
  Future<List<OmniCategory>>? _currentSearchFuture;
  double _sheetDragOffset = 0;     // 0 = fully at H_max; increases as sheet slides down

  // Crop rect corners, normalised to [0, 1] of screen dimensions
  double _cropL = 0.10, _cropT = 0.10;
  double _cropR = 0.90, _cropB = 0.90;
  static const double _kCropMinDim = 0.15;
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _capturedUiImage?.dispose();
    super.dispose();
  }

  // ── Main build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final sheetH = screenSize.height * 0.75;
    final sheetTop = screenSize.height - sheetH + _sheetDragOffset;

    return PopScope(
      canPop: false,
      onPopInvoked: (_) => _handleBackButton(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Layer 1: live camera preview OR frozen captured image
            _buildBackground(),

            // Layer 2: scanner viewfinder (live camera mode only)
            if (_scannerMode == _ScannerMode.liveCamera)
              SafeArea(child: _buildScannerUI()),

            // Layer 3: crop overlay (crop mode only)
            if (_scannerMode == _ScannerMode.cropMode)
              _buildCropOverlay(screenSize),

            // Layer 4: transparent tap zone above sheet + embedded sheet
            if (_scannerMode == _ScannerMode.capturedWithSheet) ...[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: sheetTop.clamp(0.0, screenSize.height),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _switchToCropMode,
                ),
              ),
              _buildEmbeddedSheet(screenSize, sheetH, sheetTop),
            ],

            // Layer 5: crop action bar (crop mode only)
            if (_scannerMode == _ScannerMode.cropMode)
              _buildCropActionBar(),
          ],
        ),
      ),
    );
  }

  // ── Background ─────────────────────────────────────────────────────────────

  Widget _buildBackground() {
    if (_capturedImageBytes == null) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.previewSize?.height ?? 1,
            height: controller.value.previewSize?.width ?? 1,
            child: CameraPreview(controller),
          ),
        ),
      );
    }
    return SizedBox.expand(
      child: Image.memory(_capturedImageBytes!, fit: BoxFit.cover),
    );
  }

  // ── Scanner viewfinder UI (live camera mode) ───────────────────────────────

  Widget _buildScannerUI() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Scan & Shop',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 70),
        Center(
          child: SizedBox(
            width: 265,
            height: 265,
            child: CustomPaint(
              painter: ScannerCornerPainter(color: scannerDarkPlum),
            ),
          ),
        ),
        const SizedBox(height: 55),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            scanActionButton(icon: Icons.image_outlined, label: 'Gallery'),
            const SizedBox(width: 30),
            scanActionButton(
              icon: Icons.camera_alt_outlined,
              label: 'Click',
              onTap: searchWithCamera,
            ),
            const SizedBox(width: 30),
            scanActionButton(customIcon: const BarcodeScanIcon(), label: 'Barcode'),
          ],
        ),
      ],
    );
  }

  // ── Embedded bottom sheet ──────────────────────────────────────────────────

  Widget _buildEmbeddedSheet(Size screenSize, double sheetH, double sheetTop) {
    return Positioned(
      top: sheetTop.clamp(screenSize.height - sheetH, screenSize.height),
      left: 0,
      right: 0,
      height: sheetH,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            color: scannerDarkPlum.withOpacity(0.93),
            child: Column(
              children: [
                // Drag handle — the only drag-sensitive area on the sheet
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: _onSheetDragUpdate,
                  onVerticalDragEnd: _onSheetDragEnd,
                  child: Container(
                    width: double.infinity,
                    height: 40,
                    alignment: Alignment.center,
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                // Sheet content — normal scroll behaviour below the handle
                if (_currentSearchFuture != null)
                  Expanded(
                    child: OmniProductsSheet(
                      searchFuture: _currentSearchFuture!,
                      transparent: true,
                      onDismiss: _switchToCropMode,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onSheetDragUpdate(DragUpdateDetails d) {
    final maxOffset = MediaQuery.of(context).size.height * 0.75;
    setState(() {
      _sheetDragOffset = (_sheetDragOffset + d.delta.dy).clamp(0.0, maxOffset);
    });
  }

  void _onSheetDragEnd(DragEndDetails d) {
    final screenH = MediaQuery.of(context).size.height;
    final sheetH = screenH * 0.75;
    final visibleH = sheetH - _sheetDragOffset;
    final velocity = d.primaryVelocity ?? 0;

    if (visibleH < screenH * 0.40 || velocity > 800) {
      // Crossed dismiss threshold or fast downward flick → crop mode
      setState(() {
        _scannerMode = _ScannerMode.cropMode;
        _sheetDragOffset = 0;
      });
      return;
    }

    if (velocity < -800) {
      // Fast upward flick → snap to H_max
      setState(() => _sheetDragOffset = 0.0);
      return;
    }

    if (velocity < -800) {
      // Fast upward flick → snap to H_max
      setState(() => _sheetDragOffset = 0.0);
      return;
    }

    // Default: always snap back to H_max (75% height)
    setState(() => _sheetDragOffset = 0.0);
  }

  // ── Crop overlay ───────────────────────────────────────────────────────────

  Widget _buildCropOverlay(Size screenSize) {
    final w = screenSize.width;
    final h = screenSize.height;
    final l = _cropL * w;
    final t = _cropT * h;
    final r = _cropR * w;
    final b = _cropB * h;
    const double touchSz = 44.0;

    return Stack(
      children: [
        // 30 % dark overlay outside the crop rect
        Positioned.fill(
          child: CustomPaint(
            painter: _CropOverlayPainter(cropRect: Rect.fromLTRB(l, t, r, b)),
          ),
        ),
        // Crop rect visual — corners + midlines (non-interactive)
        Positioned(
          left: l, top: t, width: r - l, height: b - t,
          child: IgnorePointer(
            child: CustomPaint(painter: CropRectPainter(color: scannerDarkPlum)),
          ),
        ),
        // 4 corner handles (move both axes)
        _cropHandle(l, t, touchSz, (dx, dy) {
          _cropL = (_cropL + dx / w).clamp(0.0, _cropR - _kCropMinDim);
          _cropT = (_cropT + dy / h).clamp(0.0, _cropB - _kCropMinDim);
        }),
        _cropHandle(r, t, touchSz, (dx, dy) {
          _cropR = (_cropR + dx / w).clamp(_cropL + _kCropMinDim, 1.0);
          _cropT = (_cropT + dy / h).clamp(0.0, _cropB - _kCropMinDim);
        }),
        _cropHandle(l, b, touchSz, (dx, dy) {
          _cropL = (_cropL + dx / w).clamp(0.0, _cropR - _kCropMinDim);
          _cropB = (_cropB + dy / h).clamp(_cropT + _kCropMinDim, 1.0);
        }),
        _cropHandle(r, b, touchSz, (dx, dy) {
          _cropR = (_cropR + dx / w).clamp(_cropL + _kCropMinDim, 1.0);
          _cropB = (_cropB + dy / h).clamp(_cropT + _kCropMinDim, 1.0);
        }),
        // 4 edge midpoint handles (move single axis each)
        _cropHandle((l + r) / 2, t, touchSz, (dx, dy) {
          _cropT = (_cropT + dy / h).clamp(0.0, _cropB - _kCropMinDim);
        }),
        _cropHandle((l + r) / 2, b, touchSz, (dx, dy) {
          _cropB = (_cropB + dy / h).clamp(_cropT + _kCropMinDim, 1.0);
        }),
        _cropHandle(l, (t + b) / 2, touchSz, (dx, dy) {
          _cropL = (_cropL + dx / w).clamp(0.0, _cropR - _kCropMinDim);
        }),
        _cropHandle(r, (t + b) / 2, touchSz, (dx, dy) {
          _cropR = (_cropR + dx / w).clamp(_cropL + _kCropMinDim, 1.0);
        }),
      ],
    );
  }

  /// Transparent 44 × 44 drag handle centred at (cx, cy).
  Widget _cropHandle(
      double cx, double cy, double sz, void Function(double, double) onDelta) {
    return Positioned(
      left: cx - sz / 2,
      top: cy - sz / 2,
      width: sz,
      height: sz,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => setState(() => onDelta(d.delta.dx, d.delta.dy)),
      ),
    );
  }

  // ── Crop action bar ────────────────────────────────────────────────────────

  Widget _buildCropActionBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.72)],
            ),
          ),
          child: Row(
            children: [
              TextButton(
                onPressed: _goToLiveCamera,
                child: const Text(
                  'New Scan',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: isCapturing ? null : _performCropAndSearch,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isCapturing
                        ? scannerDarkPlum.withOpacity(0.5)
                        : scannerDarkPlum,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCapturing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.check, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── State transitions ──────────────────────────────────────────────────────

  void _handleBackButton() {
    switch (_scannerMode) {
      case _ScannerMode.liveCamera:
        Navigator.of(context).pop();
      case _ScannerMode.capturedWithSheet:
        if (_cropAttemptCount == 0) {
          // First scan, no crop yet → go straight to live camera
          _goToLiveCamera();
        } else {
          // Had previous crops → show crop mode for further adjustments
          _switchToCropMode();
        }
      case _ScannerMode.cropMode:
        _goToLiveCamera();
    }
  }

  void _switchToCropMode() {
    setState(() {
      _scannerMode = _ScannerMode.cropMode;
      _sheetDragOffset = 0;
    });
  }

  void _goToLiveCamera() {
    _capturedUiImage?.dispose();
    setState(() {
      _scannerMode = _ScannerMode.liveCamera;
      _capturedImageBytes = null;
      _capturedUiImage = null;
      _cropAttemptCount = 0;
      _currentSearchFuture = null;
      _sheetDragOffset = 0;
      _cropL = 0.10; _cropT = 0.10; _cropR = 0.90; _cropB = 0.90;
    });
    resumeCameraPreview();
  }

  // ── Crop & re-search ───────────────────────────────────────────────────────

  Future<void> _performCropAndSearch() async {
    if (_capturedUiImage == null || _capturedImageBytes == null || isCapturing) return;

    final croppedBytes = await _cropImageToBytes(
      _capturedUiImage!, _cropL, _cropT, _cropR, _cropB,
    );
    _cropAttemptCount++;

    final screenH = MediaQuery.of(context).size.height;
    final sheetH = screenH * 0.75;

    final future = captureAndSearchProducts(croppedBytes: croppedBytes);
    setState(() {
      _currentSearchFuture = future;
      _scannerMode = _ScannerMode.capturedWithSheet;
      // Always open at H_max
      _sheetDragOffset = 0.0;
    });
  }

  Future<Uint8List> _cropImageToBytes(
    ui.Image img,
    double normL, double normT, double normR, double normB,
  ) async {
    final srcW = img.width.toDouble();
    final srcH = img.height.toDouble();
    final srcRect =
        Rect.fromLTRB(normL * srcW, normT * srcH, normR * srcW, normB * srcH);
    final dstW = srcRect.width.round().clamp(1, 9999999);
    final dstH = srcRect.height.round().clamp(1, 9999999);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      img,
      srcRect,
      Rect.fromLTWH(0, 0, dstW.toDouble(), dstH.toDouble()),
      Paint(),
    );
    final picture = recorder.endRecording();
    final croppedImg = await picture.toImage(dstW, dstH);
    final byteData = await croppedImg.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<ui.Image> _decodeUiImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Widget scanActionButton({
    required String label,
    IconData? icon,
    Widget? customIcon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [

          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.12),
            ),
            child: Center(
              child: customIcon ??
                  Icon(
                    icon,
                    color: Colors.white,
                    size: 32,
                  ),
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
      ),
    );
  }

  void searchWithCamera() {
    if (isCapturing || controller.value.isTakingPicture) return;

    // Reset crop state for a fresh scan
    _cropL = 0.10; _cropT = 0.10; _cropR = 0.90; _cropB = 0.90;
    _cropAttemptCount = 0;

    final future = captureAndSearchProducts();
    setState(() {
      _currentSearchFuture = future;
      _scannerMode = _ScannerMode.capturedWithSheet;
      _sheetDragOffset = 0;
    });
  }

  /// Captures a new photo (or uses [croppedBytes] for a re-search) and calls
  /// the backend. Does NOT resume camera preview — the frozen image stays
  /// visible for potential follow-up crops.
  Future<List<OmniCategory>> captureAndSearchProducts({Uint8List? croppedBytes}) async {
    setState(() => isCapturing = true);

    try {
      final Uint8List imageBytes;

      if (croppedBytes != null) {
        // Re-search with a cropped region — use the provided bytes directly.
        imageBytes = croppedBytes;
      } else {
        // Initial capture — take photo and store original for future crops.
        final photo = await controller.takePicture();
        imageBytes = await photo.readAsBytes();
        // Store immediately so the UI shows the frozen image right away.
        if (mounted) setState(() => _capturedImageBytes = imageBytes);
        // Decode for dart:ui crop ops — fire and forget (network call is slower).
        _decodeUiImage(imageBytes).then((img) {
          if (mounted) setState(() => _capturedUiImage = img);
        });
      }

      final request = http.MultipartRequest('POST', Uri.parse(omniSearchEndpoint));
      request.files.add(
        http.MultipartFile.fromBytes('image', imageBytes, filename: 'scan.jpg'),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException(
            'The backend did not respond in time. Check Wi-Fi/firewall.',
          );
        },
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OmniSearchException(
          readErrorMessage(response.body) ??
              'Search failed with status ${response.statusCode}.',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final categoriesJson = data['categories'];
      List<OmniCategory> parsedCategories = [];

      if (categoriesJson is List) {
        parsedCategories = categoriesJson
            .whereType<Map<String, dynamic>>()
            .map(OmniCategory.fromJson)
            .toList();
      } else {
        final productsJson = data['products'];
        if (productsJson is List) {
          parsedCategories = [
            OmniCategory(
              id: 'all',
              title: 'All Matches',
              products: productsJson
                  .whereType<Map<String, dynamic>>()
                  .map(OmniProduct.fromJson)
                  .toList(),
            ),
          ];
        }
      }

      return _fillMissingPhonePePrices(parsedCategories);
    } finally {
      // Do NOT resume camera preview — frozen image stays for crop mode.
      if (mounted) setState(() => isCapturing = false);
    }
  }

  bool _hasPriceFetched(OmniProduct product) {
    if (product.price.isEmpty) return false;
    final cleaned = product.price.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleaned) != null;
  }

  double? _parsePriceToDouble(String priceStr) {
    if (priceStr.isEmpty) return null;
    final cleaned = priceStr.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleaned);
  }

  List<OmniCategory> _fillMissingPhonePePrices(List<OmniCategory> categories) {
    final result = <OmniCategory>[];

    for (final category in categories) {
      final products = category.products;
      final phonePeProducts = <OmniProduct>[];
      final missingPricePhonePeProducts = <OmniProduct>[];
      final fetchedPrices = <double>[];

      for (final product in products) {
        final hasPhonePe = isProductPhonePeEnabled(product, products);
        if (hasPhonePe) {
          phonePeProducts.add(product);
          if (!_hasPriceFetched(product)) {
            missingPricePhonePeProducts.add(product);
          }
        }
        
        if (_hasPriceFetched(product)) {
          final parsedPrice = _parsePriceToDouble(product.price);
          if (parsedPrice != null) {
            fetchedPrices.add(parsedPrice);
          }
        }
      }

      if (missingPricePhonePeProducts.isEmpty) {
        result.add(category);
        continue;
      }

      double avgPrice;
      if (fetchedPrices.isNotEmpty) {
        final sum = fetchedPrices.reduce((a, b) => a + b);
        avgPrice = sum / fetchedPrices.length;
      } else {
        avgPrice = 1000.0 + math.Random().nextInt(9001);
      }

      final updatedProducts = <OmniProduct>[];
      for (final product in products) {
        final hasPhonePe = isProductPhonePeEnabled(product, products);
        final isPriceFetched = _hasPriceFetched(product);
        
        if (hasPhonePe && !isPriceFetched) {
          double discountPct;
          if (missingPricePhonePeProducts.length == 1) {
            discountPct = 0.12;
          } else {
            discountPct = (math.Random().nextDouble() * 15.0) / 100.0;
          }
          
          final calculatedPrice = avgPrice * (1.0 - discountPct);
          final formattedPrice = "₹${calculatedPrice.toStringAsFixed(0)}";
          updatedProducts.add(product.copyWith(price: formattedPrice));
        } else {
          updatedProducts.add(product);
        }
      }

      result.add(OmniCategory(
        id: category.id,
        title: category.title,
        products: updatedProducts,
      ));
    }

    return result;
  }

  String? readErrorMessage(String body) {
    try {
      final data = jsonDecode(body);

      if (data is Map<String, dynamic>) {
        final detail = data['detail']?.toString();
        final error = data['error']?.toString();

        if (detail != null && detail.isNotEmpty) {
          return detail;
        }

        if (error != null && error.isNotEmpty) {
          return error;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<void> resumeCameraPreview() async {
    try {
      await controller.resumePreview();
    } catch (_) {
      // Some devices keep preview running after capture, so resume can fail.
    }
  }

  void showSimilarProductsSheet(BuildContext context) {
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

class OmniProductsSheet extends StatelessWidget {
  const OmniProductsSheet({
    super.key,
    required this.searchFuture,
    this.onDismiss,
    this.transparent = false,
  });

  final Future<List<OmniCategory>> searchFuture;
  /// Called when the user taps the close button. If null, falls back to
  /// [Navigator.pop] (used when sheet is a modal).
  final VoidCallback? onDismiss;
  /// When true, omits the background decoration and SafeArea so the
  /// embedding widget can provide its own frosted container.
  final bool transparent;

  static const Color sheetBackground = Color(0xFF360816);
  static const Color cardBackground = Colors.white;
  static const Color textDark = Color(0xFF231A1A);
  static const Color textMuted = Color(0xFF6E6257);
  static const Color plum = Color(0xFF360816);

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: const EdgeInsets.all(22),
      decoration: transparent
          ? null
          : const BoxDecoration(
              color: sheetBackground,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
      constraints: transparent
          ? null
          : BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.78,
              minHeight: 430,
            ),
      child: FutureBuilder<List<OmniCategory>>(
        future: searchFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const OmniPhonePeRadarLoader();
          }

          if (snapshot.hasError) {
            return OmniSheetMessage(
              icon: const Icon(Icons.error_outline, color: Colors.white, size: 42),
              title: 'Search failed',
              message: snapshot.error.toString(),
            );
          }

          final categories = snapshot.data ?? [];
          final totalProducts = categories.fold<int>(
            0, (total, cat) => total + cat.products.length);

          if (totalProducts == 0) {
            return OmniSheetMessage(
              icon: const Icon(Icons.search_off, color: Colors.white, size: 42),
              title: 'No products found',
              message: 'Try again with the product clearly in frame.',
              onClose: onDismiss,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Similar Products Found',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (onDismiss != null) {
                        onDismiss!();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  children: [
                    for (final category in categories)
                      categoryRail(context, category),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    return transparent ? body : SafeArea(child: body);
  }

  Widget categoryRail(
    BuildContext context,
    OmniCategory category,
  ) {
    final products = category.products;
    final visibleProducts = products.take(8).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [

              Flexible(
                child: Text(
                  category.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  products.length.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 182,
            child: products.isEmpty
                ? emptyCategoryCard()
                : ListView.separated(

                    scrollDirection: Axis.horizontal,
                    itemCount: visibleProducts.length + 1,
                    separatorBuilder: (_, __) {
                      return const SizedBox(width: 12);
                    },
                    itemBuilder: (context, index) {
                      if (index == visibleProducts.length) {
                        return viewCategoryButton(context, category);
                      }

                      final product = visibleProducts[index];
                      final hasPhonePe = isProductPhonePeEnabled(product, products);
                      return railProductCard(context, product, hasPhonePe);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget emptyCategoryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(
        child: Text(
          "No matches in this category",
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget railProductCard(BuildContext context, OmniProduct product, bool hasPhonePe) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (hasPhonePe) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PhonePeCheckoutScreen(product: product),
              ),
            );
          } else {
            _nativeChannel.invokeMethod('launchUrl', {'url': product.shoppingLink});
          }
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 126,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  productImage(106, 68, product),
                  if (hasPhonePe)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5F259F), // PhonePe Purple
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 3,
                              offset: const Offset(0, 1.5),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'पे',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Roboto',
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 13,
                        height: 1.18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.source.isEmpty ? product.domain : product.source,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (product.price.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        product.price,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: plum,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget viewCategoryButton(

    BuildContext context,
    OmniCategory category,
  ) {
    return SizedBox(
      width: 72,
      child: Center(
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
                pageBuilder: (_, __, ___) {
                  return CategoryProductsPage(
                    category: category,
                  );
                },
              ),
            );
          },
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_forward,
              color: plum,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget productTile(OmniProduct product) {
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
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(14),
            ),
            child: product.image.isEmpty
                ? const Icon(
                    Icons.shopping_bag,
                    color: Colors.white,
                  )
                : Image.network(
                    product.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return const Icon(
                        Icons.shopping_bag,
                        color: Colors.white,
                      );
                    },
                  ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [

                Text(
                  product.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  product.source.isEmpty
                      ? "Online result"
                      : product.source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [

              if (product.price.isNotEmpty)
                Text(
                  product.price,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Color(0xFF360816),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  "View",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget productImage(
    double width,
    double height,
    OmniProduct product,
  ) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F0E2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: product.image.isEmpty
          ? const Icon(
              Icons.shopping_bag,
              color: textMuted,
            )
          : Image.network(
              product.image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return const Icon(
                  Icons.shopping_bag,
                  color: textMuted,
                );
              },
            ),
    );
  }
}

class CategoryProductsPage extends StatelessWidget {
  const CategoryProductsPage({
    super.key,
    required this.category,
  });

  final OmniCategory category;

  static const Color pageBackground = Color(0xFF360816);
  static const Color cardBackground = Colors.white;
  static const Color textDark = Color(0xFF231A1A);
  static const Color textMuted = Color(0xFF6E6257);
  static const Color plum = Color(0xFF360816);

  @override
  Widget build(BuildContext context) {
    final products = category.products.take(25).toList();

    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: Column(
          children: [

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              child: Row(
                children: [

                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),

                  const SizedBox(width: 4),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        Text(
                          category.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          "${products.length} results",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                itemCount: products.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.68,
                ),
                itemBuilder: (context, index) {
                  final product = products[index];
                  final hasPhonePe = isProductPhonePeEnabled(product, category.products);
                  return categoryProductCard(context, product, hasPhonePe);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget categoryProductCard(BuildContext context, OmniProduct product, bool hasPhonePe) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (hasPhonePe) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PhonePeCheckoutScreen(product: product),
              ),
            );
          } else {
            _nativeChannel.invokeMethod('launchUrl', {'url': product.shoppingLink});
          }
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  OmniProductsSheet.productImage(
                    double.infinity,
                    112,
                    product,
                  ),
                  if (hasPhonePe)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5F259F), // PhonePe Purple
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 3,
                              offset: const Offset(0, 1.5),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'पे',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Roboto',
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                product.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: textDark,
                  fontSize: 14,
                  height: 1.18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                product.source.isEmpty ? product.domain : product.source,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.price.isEmpty ? "View item" : product.price,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: plum,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: plum,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      "View",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class OmniSheetMessage extends StatelessWidget {
  const OmniSheetMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.onClose,
  });

  final Widget icon;
  final String title;
  final String message;
  final VoidCallback? onClose;

  static const Color textDark = Color(0xFF231A1A);
  static const Color textMuted = Color(0xFF6E6257);
  static const Color plum = Color(0xFF360816);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          SizedBox(
            width: 48,
            height: 48,
            child: Center(child: icon),
          ),

          const SizedBox(height: 18),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 22),

          TextButton(
            onPressed: () {
              if (onClose != null) {
                onClose!();
              } else {
                Navigator.of(context).pop();
              }
            },
            child: const Text(
              'Close',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScannerBlurClipper extends CustomClipper<Path> {
  const ScannerBlurClipper(this.scannerRect);

  final Rect scannerRect;

  @override
  Path getClip(Size size) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(
        RRect.fromRectAndRadius(
          scannerRect,
          const Radius.circular(28),
        ),
      );
  }

  @override
  bool shouldReclip(ScannerBlurClipper oldClipper) {
    return oldClipper.scannerRect != scannerRect;
  }
}

class BarcodeScanIcon extends StatelessWidget {
  const BarcodeScanIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 36,
      height: 36,
      child: CustomPaint(
        painter: BarcodeScanIconPainter(),
      ),
    );
  }
}

class BarcodeScanIconPainter extends CustomPainter {
  const BarcodeScanIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final corner = size.width * 0.23;
    final inset = size.width * 0.04;
    final right = size.width - inset;
    final bottom = size.height - inset;

    canvas
      ..drawLine(
        Offset(inset, corner),
        Offset(inset, inset),
        paint,
      )
      ..drawLine(
        Offset(inset, inset),
        Offset(corner, inset),
        paint,
      )
      ..drawLine(
        Offset(size.width - corner, inset),
        Offset(right, inset),
        paint,
      )
      ..drawLine(
        Offset(right, inset),
        Offset(right, corner),
        paint,
      )
      ..drawLine(
        Offset(inset, size.height - corner),
        Offset(inset, bottom),
        paint,
      )
      ..drawLine(
        Offset(inset, bottom),
        Offset(corner, bottom),
        paint,
      )
      ..drawLine(
        Offset(size.width - corner, bottom),
        Offset(right, bottom),
        paint,
      )
      ..drawLine(
        Offset(right, bottom),
        Offset(right, size.height - corner),
        paint,
      );

    final barPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    final bars = [
      (0.28, 0.34, 0.76),
      (0.38, 0.34, 0.66),
      (0.48, 0.34, 0.76),
      (0.58, 0.34, 0.66),
      (0.68, 0.34, 0.76),
      (0.78, 0.34, 0.66),
    ];

    for (final bar in bars) {
      final x = size.width * bar.$1;
      canvas.drawLine(
        Offset(x, size.height * bar.$2),
        Offset(x, size.height * bar.$3),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}

class ScannerCornerPainter extends CustomPainter {
  const ScannerCornerPainter({
    this.color = const Color(0xFF7B1FFF),
  });

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {

    const double padding = 18;
    const double cornerLength = 32;
    const double radius = 16;
    const double strokeWidth = 4;

    final paint = Paint()
      ..color = color
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
    return oldDelegate is! ScannerCornerPainter ||
        oldDelegate.color != color;
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CROP FEATURE: CROP RECT PAINTER & OVERLAY PAINTER
// ════════════════════════════════════════════════════════════════════════════

/// Draws the interactive crop rectangle on the captured image.
/// Style: 4 rounded L-corner brackets + 4 edge midpoint lines, identical in
/// appearance to [ScannerCornerPainter]. No connecting lines between corners.
class CropRectPainter extends CustomPainter {
  const CropRectPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const double arm = 26.0;    // length of each L-bracket arm
    const double radius = 12.0; // corner arc radius
    const double midLen = 24.0; // length of edge midpoint line

    final w = size.width;
    final h = size.height;

    // ── TOP LEFT ─────────────────────────────────────────────────────────────
    canvas.drawArc(
        Rect.fromLTWH(0, 0, radius * 2, radius * 2), math.pi, math.pi / 2, false, paint);
    canvas.drawLine(Offset(radius, 0), Offset(arm, 0), paint);
    canvas.drawLine(Offset(0, radius), Offset(0, arm), paint);

    // ── TOP RIGHT ────────────────────────────────────────────────────────────
    canvas.drawArc(
        Rect.fromLTWH(w - radius * 2, 0, radius * 2, radius * 2), -math.pi / 2, math.pi / 2, false, paint);
    canvas.drawLine(Offset(w - radius, 0), Offset(w - arm, 0), paint);
    canvas.drawLine(Offset(w, radius), Offset(w, arm), paint);

    // ── BOTTOM LEFT ──────────────────────────────────────────────────────────
    canvas.drawArc(
        Rect.fromLTWH(0, h - radius * 2, radius * 2, radius * 2), math.pi / 2, math.pi / 2, false, paint);
    canvas.drawLine(Offset(radius, h), Offset(arm, h), paint);
    canvas.drawLine(Offset(0, h - radius), Offset(0, h - arm), paint);

    // ── BOTTOM RIGHT ─────────────────────────────────────────────────────────
    canvas.drawArc(
        Rect.fromLTWH(w - radius * 2, h - radius * 2, radius * 2, radius * 2), 0, math.pi / 2, false, paint);
    canvas.drawLine(Offset(w - radius, h), Offset(w - arm, h), paint);
    canvas.drawLine(Offset(w, h - radius), Offset(w, h - arm), paint);

    // ── EDGE MIDPOINT LINES ───────────────────────────────────────────────────
    // Top: horizontal segment centred on the top side
    canvas.drawLine(Offset(w / 2 - midLen / 2, 0), Offset(w / 2 + midLen / 2, 0), paint);
    // Bottom: horizontal segment centred on the bottom side
    canvas.drawLine(Offset(w / 2 - midLen / 2, h), Offset(w / 2 + midLen / 2, h), paint);
    // Left: vertical segment centred on the left side
    canvas.drawLine(Offset(0, h / 2 - midLen / 2), Offset(0, h / 2 + midLen / 2), paint);
    // Right: vertical segment centred on the right side
    canvas.drawLine(Offset(w, h / 2 - midLen / 2), Offset(w, h / 2 + midLen / 2), paint);
  }

  @override
  bool shouldRepaint(CropRectPainter old) => old.color != color;
}

/// Paints a 30 % dark overlay on the region OUTSIDE [cropRect], leaving
/// the inside at full image brightness.
class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter({required this.cropRect});
  final Rect cropRect;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRect(cropRect),
      Paint()..color = Colors.black.withOpacity(0.30),
    );
  }

  @override
  bool shouldRepaint(_CropOverlayPainter old) => old.cropRect != cropRect;
}

// ==========================================
// PHONEPE PARTNER CHECKOUT FLOW IMPLEMENTATION
// ==========================================

class PhonePeCheckoutScreen extends StatefulWidget {
  final OmniProduct product;
  const PhonePeCheckoutScreen({super.key, required this.product});

  @override
  State<PhonePeCheckoutScreen> createState() => _PhonePeCheckoutScreenState();
}

class _PhonePeCheckoutScreenState extends State<PhonePeCheckoutScreen> {
  bool isLoading = true;
  String name = 'Prekshit';
  String address = '246, Green Glen Layout, Belandur, Bangalore';
  String contact = '9999888822';
  String creditCard = '**** **** **** *007';
  
  String selectedPayment = 'PhonePe Credit Card • 1007';
  bool isProcessingPayment = false;
  int quantity = 1;

  late String deliveryTime;

  // Parses the raw price string (e.g. "₹1,299" or "$29.99") to a double.
  double _parsePrice(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  // Returns the per-unit price formatted as ₹X.
  String get _unitPrice => widget.product.price;

  // Returns the total price (unit × quantity) formatted as ₹X.
  String get _totalPrice {
    final unit = _parsePrice(widget.product.price);
    if (unit == 0) return widget.product.price.isEmpty ? '₹0' : widget.product.price;
    final total = unit * quantity;
    return '₹${total.toStringAsFixed(total == total.roundToDouble() ? 0 : 2)}';
  }

  // True when UPI Lite should be disabled (total = unit × qty > ₹2000).
  bool get _isUpiLiteDisabled => (_parsePrice(widget.product.price) * quantity) > 2000;

  @override
  void initState() {
    super.initState();
    _calculateDeliveryTime();
    _fetchUserProfile();
  }

  void _calculateDeliveryTime() {
    final catId = widget.product.categoryId;
    final r = widget.product.title.hashCode.abs();
    if (catId == 'quick_commerce') {
      final mins = 15 + (r % 45);
      deliveryTime = "$mins mins";
    } else if (catId == 'indian_ecommerce' || catId == 'second_hand') {
      final days = 2 + (r % 6);
      deliveryTime = "$days days";
    } else if (catId == 'bulk') {
      final days = 7 + (r % 9);
      deliveryTime = "$days days";
    } else if (catId == 'international') {
      final days = 15 + (r % 16);
      deliveryTime = "$days days";
    } else {
      deliveryTime = "4 days";
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      final profileUrl = omniSearchEndpoint.replaceAll('/visual-search', '/user-profile');
      final res = await http.get(Uri.parse(profileUrl)).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          name = data['name'] ?? name;
          address = data['address'] ?? address;
          contact = data['contact'] ?? contact;
          creditCard = data['creditCard'] ?? creditCard;
          isLoading = false;
        });
        return;
      }
    } catch (_) {
      // Fallback on error/offline
    }
    setState(() {
      isLoading = false;
    });
  }

  void _processPayment() {
    setState(() {
      isProcessingPayment = true;
    });
    Future.delayed(const Duration(milliseconds: 2200), () {
      setState(() {
        isProcessingPayment = false;
      });
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PaymentSuccessScreen(
            product: widget.product,
            deliveryTime: deliveryTime,
            paymentMethod: selectedPayment,
            name: name,
            address: address,
            contact: contact,
            totalPrice: _totalPrice,
            quantity: quantity,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color plum = Color(0xFF360816);
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: plum,
        title: const Text('PhonePe Checkout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator(color: plum))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader('Delivery Address'),
                      Card(
                        color: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person, color: plum, size: 20),
                                  const SizedBox(width: 8),
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on, color: plum, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(address, style: const TextStyle(color: Colors.black87, height: 1.3)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.phone, color: plum, size: 20),
                                  const SizedBox(width: 8),
                                  Text(contact, style: const TextStyle(color: Colors.black87)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      _buildHeader('Product Details'),
                      Card(
                        color: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 70,
                                    height: 70,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F0E2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: widget.product.image.isEmpty
                                        ? const Icon(Icons.shopping_bag, color: plum)
                                        : Image.network(
                                            widget.product.image,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag, color: plum),
                                          ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.product.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _unitPrice,
                                              style: const TextStyle(color: plum, fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: plum.withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                widget.product.categoryTitle,
                                                style: const TextStyle(color: plum, fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // ── Quantity Counter ──
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
                                  Row(
                                    children: [
                                      _qtyButton(
                                        icon: Icons.remove,
                                        onTap: quantity > 1 ? () => setState(() => quantity--) : null,
                                      ),
                                      Container(
                                        width: 36,
                                        alignment: Alignment.center,
                                        child: Text(
                                          '$quantity',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ),
                                      _qtyButton(
                                        icon: Icons.add,
                                        onTap: quantity < 99 ? () => setState(() => quantity++) : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      Card(
                        color: plum.withOpacity(0.04),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              const Icon(Icons.local_shipping, color: plum),
                              const SizedBox(width: 10),
                              const Text('Estimated Delivery: ', style: TextStyle(fontWeight: FontWeight.w600)),
                              Text(deliveryTime, style: const TextStyle(color: plum, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      _buildHeader('Select Option to Pay'),
                      Column(
                        children: [
                          _buildPaymentRadio('PhonePe UPI', Icons.account_balance_wallet),
                          _buildPaymentRadio('PhonePe Wallet', Icons.wallet_giftcard),
                          _buildPaymentRadio('UPI Lite', Icons.bolt, disabled: _isUpiLiteDisabled),
                          _buildPaymentRadio('PhonePe Credit Card • 1007', Icons.credit_card),
                        ],
                      ),
                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _processPayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: plum,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'Pay Total: $_totalPrice${quantity > 1 ? " ($quantity items)" : ""}',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
          if (isProcessingPayment)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Card(
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: plum),
                        SizedBox(height: 16),
                        Text(
                          'Processing Payment via PhonePe...',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF6E6257)),
      ),
    );
  }

  // Small circular +/- button for the quantity counter.
  Widget _qtyButton({required IconData icon, VoidCallback? onTap}) {
    final bool active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? const Color(0xFF360816) : Colors.grey.shade200,
        ),
        child: Icon(icon, size: 16, color: active ? Colors.white : Colors.grey),
      ),
    );
  }

  Widget _buildPaymentRadio(String value, IconData icon, {bool disabled = false}) {
    final bool isSelected = selectedPayment == value && !disabled;
    final Color labelColor = disabled
        ? Colors.grey.shade400
        : isSelected ? const Color(0xFF5F259F) : Colors.black87;
    final Color iconColor = disabled
        ? Colors.grey.shade300
        : isSelected ? const Color(0xFF5F259F) : Colors.grey;

    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: Card(
        color: disabled ? Colors.grey.shade50 : Colors.white,
        elevation: isSelected ? 2 : 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected ? const Color(0xFF5F259F) : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        margin: const EdgeInsets.only(bottom: 10),
        child: Stack(
          children: [
            RadioListTile<String>(
              value: value,
              groupValue: selectedPayment,
              activeColor: const Color(0xFF5F259F),
              title: Row(
                children: [
                  Icon(icon, color: iconColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: labelColor,
                          ),
                        ),
                        if (disabled)
                          const Text(
                            'Not available above ₹2,000',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              onChanged: disabled ? null : (String? val) {
                if (val != null) setState(() => selectedPayment = val);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentSuccessScreen extends StatelessWidget {
  final OmniProduct product;
  final String deliveryTime;
  final String paymentMethod;
  final String name;
  final String address;
  final String contact;
  final String totalPrice;
  final int quantity;

  const PaymentSuccessScreen({
    super.key,
    required this.product,
    required this.deliveryTime,
    required this.paymentMethod,
    required this.name,
    required this.address,
    required this.contact,
    required this.totalPrice,
    required this.quantity,
  });

  @override
  Widget build(BuildContext context) {
    const Color plum = Color(0xFF360816);
    const Color phonepePurple = Color(0xFF5F259F);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: phonepePurple,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: phonepePurple.withOpacity(0.35),
                      blurRadius: 20,
                      spreadRadius: 4,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 56,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Payment Successful',
                style: TextStyle(
                  color: phonepePurple,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your order has been placed successfully!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 36),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Amount Paid', totalPrice, isBold: true),
                    const Divider(height: 24),
                    _buildSummaryRow('Transaction ID', 'TXN${DateTime.now().millisecondsSinceEpoch.toString().substring(3)}'),
                    const SizedBox(height: 10),
                    _buildSummaryRow('Payment Via', paymentMethod.split(RegExp(r' [•(]')).first),
                    const SizedBox(height: 10),
                    _buildSummaryRow('Delivery Estimate', deliveryTime, valColor: plum, valBold: true),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => InvoiceScreen(
                          product: product,
                          deliveryTime: deliveryTime,
                          paymentMethod: paymentMethod,
                          name: name,
                          address: address,
                          contact: contact,
                          totalPrice: totalPrice,
                          quantity: quantity,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: plum,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'View Invoice',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? valColor, bool valBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: (isBold || valBold) ? FontWeight.bold : FontWeight.normal,
            color: valColor ?? (isBold ? Colors.black : Colors.black87),
            fontSize: isBold ? 16 : 14,
          ),
        ),
      ],
    );
  }
}

class InvoiceScreen extends StatelessWidget {
  final OmniProduct product;
  final String deliveryTime;
  final String paymentMethod;
  final String name;
  final String address;
  final String contact;
  final String totalPrice;
  final int quantity;

  InvoiceScreen({
    super.key,
    required this.product,
    required this.deliveryTime,
    required this.paymentMethod,
    required this.name,
    required this.address,
    required this.contact,
    required this.totalPrice,
    required this.quantity,
  });

  final GlobalKey _boundaryKey = GlobalKey();

  Future<void> _downloadInvoicePng(BuildContext context) async {
    try {
      RenderRepaintBoundary? boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Boundary not found');
      
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List? pngBytes = byteData?.buffer.asUint8List();
      
      if (pngBytes == null) throw Exception('Failed to encode PNG');

      final orderId = _getOrderId();
      final fileName = "Omni_Order_${orderId}.png";
      
      final bool? success = await _nativeChannel.invokeMethod<bool>('saveImageToDownloads', {
        'bytes': pngBytes,
        'fileName': fileName,
      });

      if (success == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF360816),
            behavior: SnackBarBehavior.floating,
            content: Text('Successfully downloaded: $fileName inside Downloads folder!'),
          ),
        );
      } else {
        throw Exception('Native storage write returned false');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          content: Text('Failed to download receipt: $e'),
        ),
      );
    }
  }

  void _shareInvoiceText() {
    final orderId = _getOrderId();
    final qtyLine = quantity > 1 ? 'Qty: $quantity × ${product.price}\n' : '';
    final text = """
========================================
       OMNI RETAIL ORDER INVOICE
========================================
Order ID: #$orderId
Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}

CUSTOMER INFORMATION
--------------------
Name: $name
Address: $address
Contact: $contact

PRODUCT SUMMARY
---------------
Product: ${product.title}
Source: ${product.source.isEmpty ? product.domain : product.source}
${qtyLine}Amount: $totalPrice
Est. Delivery: $deliveryTime

PAYMENT INFORMATION
-------------------
Method: ${paymentMethod.split(RegExp(r' [•(]')).first}
Status: Successful

Thank you for choosing PhonePe Partner Checkout!
========================================
""";
    _nativeChannel.invokeMethod('shareInvoice', {'text': text});
  }

  String _getOrderId() {
    final int hash = (product.title + name).hashCode.abs();
    return "OMN-${hash.toString().substring(0, 6)}";
  }

  @override
  Widget build(BuildContext context) {
    const Color plum = Color(0xFF360816);
    final orderId = _getOrderId();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: plum,
        title: const Text('Order Invoice', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'INVOICE',
                              style: TextStyle(
                                color: plum,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'PAID',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Order ID: #$orderId',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                            ),
                            Text(
                              'Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(thickness: 1),
                        const SizedBox(height: 12),
                        const Text(
                          'DELIVERY DETAILS',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          address,
                          style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.3),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Contact: $contact',
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                        const SizedBox(height: 12),
                        const Divider(thickness: 1),
                        const SizedBox(height: 12),
                        const Text(
                          'ORDER DETAILS',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Source: ${product.source.isEmpty ? product.domain : product.source}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  if (quantity > 1) ...[  
                                    const SizedBox(height: 4),
                                    Text(
                                      'Qty: $quantity × ${product.price}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: Text(
                                totalPrice,
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: plum),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(thickness: 1),
                        const SizedBox(height: 12),
                        _buildInvoiceItemRow('Payment Method', paymentMethod.split(RegExp(r' [•(]')).first),
                        const SizedBox(height: 6),
                        _buildInvoiceItemRow('Est. Delivery Time', deliveryTime),
                        const SizedBox(height: 16),
                        const Divider(thickness: 1.5),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL PAID',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black),
                            ),
                            Text(
                              totalPrice,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: plum),
                            ),

                          ],
                        ),
                        const SizedBox(height: 18),
                        Center(
                          child: Text(
                            'Thank you for your purchase!',
                            style: TextStyle(color: Colors.grey.shade400, fontStyle: FontStyle.italic, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => _downloadInvoicePng(context),
                      icon: const Icon(Icons.download, color: plum),
                      label: const Text('Download', style: TextStyle(color: plum, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: plum),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _shareInvoiceText,
                      icon: const Icon(Icons.share, color: Colors.white),
                      label: const Text('Share Invoice', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: plum,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
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

  Widget _buildInvoiceItemRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class OmniPhonePeRadarLoader extends StatefulWidget {
  const OmniPhonePeRadarLoader({super.key});

  @override
  State<OmniPhonePeRadarLoader> createState() => _OmniPhonePeRadarLoaderState();
}

class _OmniPhonePeRadarLoaderState extends State<OmniPhonePeRadarLoader>
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;
  int _currentStep = 0;
  Timer? _timer;

  static const List<Map<String, dynamic>> _loadingSteps = [
    {'text': 'Uploading safely... No peeking!', 'duration': 3000},
    {'text': 'Analyzing pixels... "Hmm, interesting taste."', 'duration': 1500},
    {'text': 'Asking the FETCH for answers...', 'duration': 1500},
    {'text': 'Gathering matches...', 'duration': 2000},
    {'text': 'Scanning Amazon, Flipkart, and Quick Commerce... Delivery guy is on standby.', 'duration': 3500},
    {'text': 'Sorting out the clones to find the real deal...', 'duration': 1500},
    {'text': 'Setting up the aisle. Get your digital wallet ready!', 'duration': 1000},
  ];

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _startStepping();
  }

  void _startStepping() {
    if (_currentStep < _loadingSteps.length - 1) {
      final currentDuration = _loadingSteps[_currentStep]['duration'] as int;
      _timer = Timer(Duration(milliseconds: currentDuration), () {
        if (mounted) {
          setState(() {
            _currentStep++;
          });
          _startStepping();
        }
      });
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color phonePePurple = Color(0xFF6A1BCE);
    const Color phonePeGold = Color(0xFFFFB300);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: phonePePurple.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: phonePeGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Omni Visual Search",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Finding matches in real-time...",
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(
                  Icons.close,
                  color: Colors.white60,
                  size: 20,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          
          // Progressive Checklist
          _buildChecklist(),
          
          const SizedBox(height: 24),
          
          // Shimmering Mock Product Rails
          _buildSkeletonLoader(),
          
          const SizedBox(height: 16),
          
          // Cancel/Cancel button
          Align(
            alignment: Alignment.center,
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(color: Colors.white.withOpacity(0.18)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              ),
              child: const Text(
                "Cancel Search",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklist() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_loadingSteps.length, (index) {
        final step = _loadingSteps[index];
        final stepText = step['text'] as String;
        
        final isCompleted = index < _currentStep;
        final isActive = index == _currentStep;
        
        Color textColor;
        Widget icon;
        
        if (isCompleted) {
          textColor = Colors.white.withOpacity(0.5);
          icon = const Icon(
            Icons.check_circle,
            color: Color(0xFFFFB300), // PhonePe Gold
            size: 16,
          );
        } else if (isActive) {
          textColor = Colors.white;
          icon = const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6A1BCE)),
            ),
          );
        } else {
          textColor = Colors.white.withOpacity(0.24);
          icon = Icon(
            Icons.circle_outlined,
            color: Colors.white.withOpacity(0.16),
            size: 14,
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Container(
                width: 24,
                alignment: Alignment.center,
                child: icon,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stepText,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSkeletonLoader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            ShimmerPlaceholder(
              width: 120,
              height: 14,
              borderRadius: 4,
              shimmerAnimation: _shimmerController,
            ),
            const SizedBox(width: 8),
            ShimmerPlaceholder(
              width: 24,
              height: 14,
              borderRadius: 8,
              shimmerAnimation: _shimmerController,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 164,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return Container(
                width: 114,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.04),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ShimmerPlaceholder(
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: 10,
                        shimmerAnimation: _shimmerController,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ShimmerPlaceholder(
                      width: 84,
                      height: 10,
                      borderRadius: 3,
                      shimmerAnimation: _shimmerController,
                    ),
                    const SizedBox(height: 5),
                    ShimmerPlaceholder(
                      width: 44,
                      height: 10,
                      borderRadius: 3,
                      shimmerAnimation: _shimmerController,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class ShimmerPlaceholder extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Animation<double> shimmerAnimation;

  const ShimmerPlaceholder({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
    required this.shimmerAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerAnimation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.04),
                Colors.white.withOpacity(0.16),
                Colors.white.withOpacity(0.04),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-2.0 + (shimmerAnimation.value * 4.0), -0.5),
              end: Alignment(-1.0 + (shimmerAnimation.value * 4.0), 0.5),
            ),
          ),
        );
      },
    );
  }
}

