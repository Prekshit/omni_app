import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

List<CameraDescription> cameras = [];

const String omniSearchEndpoint = String.fromEnvironment(
  'OMNI_BACKEND_URL',
  defaultValue: 'http://10.0.2.2:3000/api/visual-search',
);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [

          CameraPreview(controller),

          SafeArea(
            child: Column(
              children: [

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [

                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                        },
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),

                      const SizedBox(width: 16),

                      const Expanded(
                        child: Text(
                          "Scan & Shop",
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
                      painter: ScannerCornerPainter(
                        color: scannerDarkPlum,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 55),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [

                    scanActionButton(
                      icon: Icons.image_outlined,
                      label: "Gallery",
                    ),

                    const SizedBox(width: 30),

                    scanActionButton(
                      icon: Icons.camera_alt_outlined,
                      label: "Click",
                      onTap: searchWithCamera,
                    ),

                    const SizedBox(width: 30),

                    scanActionButton(
                      customIcon: const BarcodeScanIcon(),
                      label: "Barcode",
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
    if (isCapturing || controller.value.isTakingPicture) {
      return;
    }

    final searchFuture = captureAndSearchProducts();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      enableDrag: false,
      isDismissible: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (context) {
        return OmniProductsSheet(
          searchFuture: searchFuture,
        );
      },
    );
  }

  Future<List<OmniCategory>> captureAndSearchProducts() async {
    setState(() {
      isCapturing = true;
    });

    try {
      final photo = await controller.takePicture();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(omniSearchEndpoint),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          photo.path,
        ),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 35),
        onTimeout: () {
          throw TimeoutException(
            'The backend did not respond in time. Check Wi-Fi/firewall.',
          );
        },
      );
      final response =
          await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OmniSearchException(
          readErrorMessage(response.body) ??
              'Search failed with status ${response.statusCode}.',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final categoriesJson = data['categories'];

      if (categoriesJson is List) {
        return categoriesJson
            .whereType<Map<String, dynamic>>()
            .map(OmniCategory.fromJson)
            .toList();
      }

      final productsJson = data['products'];

      if (productsJson is! List) {
        return [];
      }

      final products = productsJson
          .whereType<Map<String, dynamic>>()
          .map(OmniProduct.fromJson)
          .toList();

      return [
        OmniCategory(
          id: 'all',
          title: 'All Matches',
          products: products,
        ),
      ];
    } finally {
      await resumeCameraPreview();

      if (mounted) {
        setState(() {
          isCapturing = false;
        });
      }
    }
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
  });

  final Future<List<OmniCategory>> searchFuture;

  static const Color sheetBackground = Color(0xFF360816);
  static const Color cardBackground = Colors.white;
  static const Color textDark = Color(0xFF231A1A);
  static const Color textMuted = Color(0xFF6E6257);
  static const Color plum = Color(0xFF360816);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: sheetBackground,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
          minHeight: 430,
        ),
        child: FutureBuilder<List<OmniCategory>>(
          future: searchFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const OmniSheetMessage(
                icon: CircularProgressIndicator(
                  color: Colors.white,
                ),
                title: "Finding similar products",
                message: "Scanning this image across product results...",
              );
            }

            if (snapshot.hasError) {
              return OmniSheetMessage(
                icon: const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 42,
                ),
                title: "Search failed",
                message: snapshot.error.toString(),
              );
            }

            final categories = snapshot.data ?? [];
            final totalProducts = categories.fold<int>(
              0,
              (total, category) => total + category.products.length,
            );

            if (totalProducts == 0) {
              return const OmniSheetMessage(
                icon: Icon(
                  Icons.search_off,
                  color: Colors.white,
                  size: 42,
                ),
                title: "No products found",
                message: "Try again with the product clearly in frame.",
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Row(
                  children: [

                    const Expanded(
                      child: Text(
                        "Similar Products Found",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    IconButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                      ),
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
      ),
    );
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
            height: 164,
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

                      return railProductCard(visibleProducts[index]);
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

  Widget railProductCard(OmniProduct product) {
    return Container(
      width: 126,
      padding: const EdgeInsets.all(10),
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

          productImage(106, 72, product),

          const SizedBox(height: 9),

          Text(
            product.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: textDark,
              fontSize: 13,
              height: 1.18,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 5),

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

          if (product.price.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              product.price,
              maxLines: 1,
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
                  childAspectRatio: 0.72,
                ),
                itemBuilder: (context, index) {
                  return categoryProductCard(products[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget categoryProductCard(OmniProduct product) {
    return Container(
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

          OmniProductsSheet.productImage(
            double.infinity,
            112,
            product,
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
    );
  }
}

class OmniSheetMessage extends StatelessWidget {
  const OmniSheetMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final Widget icon;
  final String title;
  final String message;

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
              Navigator.of(context).pop();
            },
            child: const Text(
              "Close",
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
