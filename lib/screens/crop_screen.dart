import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import '../models/crop_area.dart';

class CropScreen extends StatefulWidget {
  final String imagePath;

  const CropScreen({
    super.key,
    required this.imagePath,
  });

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  late ui.Image _uiImage;
  late Size _imageSize;

  Offset? _dragStart;
  Offset? _dragEnd;
  final List<CropArea> _cropAreas = [];
  bool _isImageLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    final image = img.decodeImage(bytes);

    if (image != null) {
      final ui.Image uiImage = await _convertImageToUiImage(image);
      setState(() {
        _uiImage = uiImage;
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
        _isImageLoaded = true;
      });
    }
  }

  Future<ui.Image> _convertImageToUiImage(img.Image image) async {
    final bytes = image.toUint8List();
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(Uint8List.fromList(bytes), (result) {
      completer.complete(result);
    });
    return completer.future;
  }

  void _onDragStart(DragStartDetails details) {
    setState(() {
      _dragStart = details.localPosition;
      _dragEnd = details.localPosition;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragEnd = details.localPosition;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dragStart != null && _dragEnd != null) {
      final cropArea = CropArea(start: _dragStart!, end: _dragEnd!);
      if (cropArea.isValid) {
        setState(() {
          _cropAreas.add(cropArea);
          _dragStart = null;
          _dragEnd = null;
        });
      }
    }
  }

  void _removeCropArea(int index) {
    setState(() {
      _cropAreas.removeAt(index);
    });
  }

  void _clearAll() {
    setState(() {
      _cropAreas.clear();
      _dragStart = null;
      _dragEnd = null;
    });
  }

  Future<void> _confirmCrop() async {
    if (_cropAreas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 1개 이상의 문제를 선택해주세요')),
      );
      return;
    }

    // 워터마크된 이미지 생성 (나중에 PDF로 사용할 이미지들을 저장)
    Navigator.of(context).pop(_cropAreas);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isImageLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('이미지 로딩 중...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('틀린 문제 선택'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 선택된 영역 개수 표시
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '선택된 문제: ${_cropAreas.length}개',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (_cropAreas.isNotEmpty)
                  TextButton.icon(
                    onPressed: _clearAll,
                    icon: const Icon(Icons.clear),
                    label: const Text('초기화'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
              ],
            ),
          ),
          // 이미지 캔버스
          Expanded(
            child: GestureDetector(
              onHorizontalDragStart: _onDragStart,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              onVerticalDragStart: _onDragStart,
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              child: Container(
                color: Colors.grey[100],
                child: FitBox(
                  child: CustomPaint(
                    painter: _CropPainter(
                      uiImage: _uiImage,
                      cropAreas: _cropAreas,
                      currentDrag: (_dragStart != null && _dragEnd != null)
                          ? CropArea(start: _dragStart!, end: _dragEnd!)
                          : null,
                    ),
                    size: _imageSize,
                  ),
                ),
              ),
            ),
          ),
          // 선택된 영역 목록
          if (_cropAreas.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                itemCount: _cropAreas.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(4),
                    child: Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: -8,
                          right: -8,
                          child: GestureDetector(
                            onTap: () => _removeCropArea(index),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          // 하단 버튼
          Container(
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
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _confirmCrop,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('완료'),
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

class _CropPainter extends CustomPainter {
  final ui.Image uiImage;
  final List<CropArea> cropAreas;
  final CropArea? currentDrag;

  _CropPainter({
    required this.uiImage,
    required this.cropAreas,
    this.currentDrag,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 이미지 그리기
    canvas.drawImage(uiImage, Offset.zero, Paint());

    // 확정된 크롭 영역 그리기
    for (int i = 0; i < cropAreas.length; i++) {
      final area = cropAreas[i];
      canvas.drawRect(
        area.rect,
        Paint()
          ..color = Colors.green.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRect(
        area.rect,
        Paint()
          ..color = Colors.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // 현재 드래그 중인 영역 그리기
    if (currentDrag != null && currentDrag!.width > 0 && currentDrag!.height > 0) {
      canvas.drawRect(
        currentDrag!.rect,
        Paint()
          ..color = Colors.blue.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRect(
        currentDrag!.rect,
        Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_CropPainter oldDelegate) => true;
}

// 이미지를 화면 크기에 맞게 조정해서 표시하는 위젯
class FitBox extends StatelessWidget {
  final Widget child;

  const FitBox({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      child: child,
    );
  }
}
