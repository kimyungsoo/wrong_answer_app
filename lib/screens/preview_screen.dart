import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import '../models/crop_area.dart';

// top-level function: compute()에서 백그라운드 isolate로 실행됨
List<Uint8List> _doCropWork(List<dynamic> args) {
  final imageBytes = args[0] as Uint8List;
  final containerWidth = args[1] as double;
  final containerHeight = args[2] as double;
  final rects = (args[3] as List).map((r) => (r as List).cast<double>()).toList();

  final image = img.decodeImage(imageBytes);
  if (image == null) return [];

  final imageWidth = image.width.toDouble();
  final imageHeight = image.height.toDouble();

  final scale = math.min(containerWidth / imageWidth, containerHeight / imageHeight);
  final renderedWidth = imageWidth * scale;
  final renderedHeight = imageHeight * scale;
  final offsetX = (containerWidth - renderedWidth) / 2;
  final offsetY = (containerHeight - renderedHeight) / 2;

  final results = <Uint8List>[];
  for (final rect in rects) {
    final left = ((rect[0] - offsetX) / scale).round().clamp(0, image.width);
    final top = ((rect[1] - offsetY) / scale).round().clamp(0, image.height);
    final right = ((rect[2] - offsetX) / scale).round().clamp(0, image.width);
    final bottom = ((rect[3] - offsetY) / scale).round().clamp(0, image.height);

    final width = right - left;
    final height = bottom - top;

    if (width > 0 && height > 0) {
      final cropped = img.copyCrop(image, x: left, y: top, width: width, height: height);
      results.add(Uint8List.fromList(img.encodeJpg(cropped, quality: 90)));
    }
  }

  return results;
}

class PreviewScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final List<CropArea> cropAreas;
  final Size containerSize;
  final int startIndex;

  const PreviewScreen({
    super.key,
    required this.imageBytes,
    required this.cropAreas,
    required this.containerSize,
    this.startIndex = 0,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late Future<List<Uint8List>> _croppedImagesFuture;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _croppedImagesFuture = _extractCroppedImages();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<List<Uint8List>> _extractCroppedImages() {
    final rects = widget.cropAreas.map((area) {
      final r = area.rect;
      return [r.left, r.top, r.right, r.bottom];
    }).toList();

    return compute(_doCropWork, [
      widget.imageBytes,
      widget.containerSize.width,
      widget.containerSize.height,
      rects,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('크롭 확인'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            icon: const Icon(Icons.home, color: Colors.white, size: 18),
            label: const Text('홈으로', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: FutureBuilder<List<Uint8List>>(
        future: _croppedImagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('이미지 처리 중...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('크롭 실패: ${snapshot.error}'));
          }

          final croppedImages = snapshot.data!;

          return Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() => _currentPage = index);
                      },
                      itemCount: croppedImages.length,
                      itemBuilder: (context, index) {
                        return Container(
                          color: Colors.grey[100],
                          child: Image.memory(
                            croppedImages[index],
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        );
                      },
                    ),
                    // 번호 배지
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '오답 ${widget.startIndex + _currentPage + 1}번',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    // 이전 버튼
                    if (croppedImages.length > 1 && _currentPage > 0)
                      Positioned(
                        left: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: () => _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            ),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.4),
                              ),
                              child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                            ),
                          ),
                        ),
                      ),
                    // 다음 버튼
                    if (croppedImages.length > 1 && _currentPage < croppedImages.length - 1)
                      Positioned(
                        right: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: () => _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            ),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.4),
                              ),
                              child: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
                            ),
                          ),
                        ),
                      ),
                    // 페이지 인디케이터
                    if (croppedImages.length > 1)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            croppedImages.length,
                            (index) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _currentPage == index
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[400],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('다시 선택'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, croppedImages),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('다음 사진 촬영'),
                      ),
                    ),
                  ],
                ),
              ),
              ),
            ],
          );
        },
      ),
    );
  }
}
