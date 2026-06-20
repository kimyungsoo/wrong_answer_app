import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../models/crop_area.dart';

class CropScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final int startIndex;

  const CropScreen({
    super.key,
    required this.imageBytes,
    this.startIndex = 0,
  });

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  Offset? _dragStart;
  Offset? _dragEnd;
  final List<CropArea> _cropAreas = [];
  Size? _containerSize;

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

    Navigator.of(context).pop((_cropAreas, _containerSize ?? const Size(400, 600)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('틀린 문제 선택'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            icon: const Icon(Icons.home, color: Colors.white, size: 18),
            label: const Text('홈으로', style: TextStyle(color: Colors.white)),
          ),
        ],
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
                  '선택된 문제: ${_cropAreas.length}개 (오답 ${widget.startIndex + 1}번~)',
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                _containerSize = constraints.biggest;
                return GestureDetector(
                  onHorizontalDragStart: _onDragStart,
                  onHorizontalDragUpdate: _onDragUpdate,
                  onHorizontalDragEnd: _onDragEnd,
                  onVerticalDragStart: _onDragStart,
                  onVerticalDragUpdate: _onDragUpdate,
                  onVerticalDragEnd: _onDragEnd,
                  child: Container(
                    color: Colors.grey[100],
                    child: Stack(
                      children: [
                        Image.memory(
                          widget.imageBytes,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                        CustomPaint(
                          painter: _CropAreaPainter(
                            cropAreas: _cropAreas,
                            currentDrag: (_dragStart != null && _dragEnd != null)
                                ? CropArea(start: _dragStart!, end: _dragEnd!)
                                : null,
                          ),
                          size: Size.infinite,
                        ),
                        // 힌트 텍스트
                        if (_cropAreas.isEmpty && _dragStart == null)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '틀린 문제를 드래그하여 자르세요',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        // 선택된 영역 목록 (오버레이)
                        if (_cropAreas.isNotEmpty)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 100,
                              color: Colors.black.withValues(alpha: 0.55),
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.all(8),
                                itemCount: _cropAreas.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          width: 72,
                                          height: 72,
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.white, width: 2),
                                            borderRadius: BorderRadius.circular(8),
                                            color: Colors.white.withValues(alpha: 0.2),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${widget.startIndex + index + 1}',
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: -6,
                                          right: -6,
                                          child: GestureDetector(
                                            onTap: () => _removeCropArea(index),
                                            child: Container(
                                              width: 22,
                                              height: 22,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.red,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                size: 13,
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
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // 하단 버튼
          SafeArea(
            top: false,
            child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
          ),
        ],
      ),
    );
  }
}

class _CropAreaPainter extends CustomPainter {
  final List<CropArea> cropAreas;
  final CropArea? currentDrag;

  _CropAreaPainter({
    required this.cropAreas,
    this.currentDrag,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final area in cropAreas) {
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
  bool shouldRepaint(_CropAreaPainter oldDelegate) => true;
}
