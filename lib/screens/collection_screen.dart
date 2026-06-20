import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../services/pdf_service.dart';
import '../services/pdf_generator.dart';
import '../services/pdf_storage_service.dart';
import 'pdf_viewer_screen.dart';

// 백그라운드 isolate에서 이미지 크기 계산
List<Map<String, double>> _computeImageSizes(List<Uint8List> imageBytesList) {
  return imageBytesList.map((bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded != null) {
      return {'w': decoded.width.toDouble(), 'h': decoded.height.toDouble()};
    }
    return {'w': 100.0, 'h': 100.0};
  }).toList();
}

class CollectionScreen extends StatefulWidget {
  final List<Uint8List> crops;

  const CollectionScreen({super.key, required this.crops});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  bool _twoColumns = false;
  bool _isGenerating = false;
  List<Size>? _imageSizes;

  @override
  void initState() {
    super.initState();
    _loadImageSizes();
  }

  Future<void> _loadImageSizes() async {
    final sizeData = await compute(_computeImageSizes, widget.crops);
    if (mounted) {
      setState(() {
        _imageSizes = sizeData.map((m) => Size(m['w']!, m['h']!)).toList();
      });
    }
  }

  Future<void> _generatePdf() async {
    // 제목 입력 다이얼로그
    final titleController = TextEditingController(text: '오답모음집');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PDF 제목 설정'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '파일 제목을 입력하세요',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.pop(context, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('생성'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final title = titleController.text.trim().isEmpty
        ? '오답모음집'
        : titleController.text.trim();

    if (!mounted) return;
    setState(() => _isGenerating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final croppedImageObjects = <CroppedImage>[];
      for (int i = 0; i < widget.crops.length; i++) {
        final size = _imageSizes?[i];
        croppedImageObjects.add(CroppedImage(
          imageData: widget.crops[i],
          width: size?.width ?? 100,
          height: size?.height ?? 100,
        ));
      }

      final Uint8List pdfBytes;
      if (_twoColumns) {
        final pages = PdfService.arrangeImagesOnPagesColumns(croppedImageObjects, 2);
        pdfBytes = await PdfGenerator.generatePdfColumns(pages, 2);
      } else {
        final pages = PdfService.arrangeImagesOnPages(croppedImageObjects);
        pdfBytes = await PdfGenerator.generatePdf(pages);
      }

      await PdfStorageService.save(
        title,
        pdfBytes,
        crops: widget.crops,
        twoColumns: _twoColumns,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(pdfBytes: pdfBytes, title: title),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('PDF 생성 실패: $e')));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // 페이지별 컬럼별 이미지 인덱스 계산
  // 반환: [ page[ column[ imgIdx ] ] ]
  List<List<List<int>>> _computeLayout(
    List<Size> imageSizes,
    double columnWidth,
    double usableHeight,
    int numColumns,
    double spacing,
  ) {
    final pages = <List<List<int>>>[];
    var currentPage = List.generate(numColumns, (_) => <int>[]);
    var columnHeights = List.filled(numColumns, 0.0);
    var currentCol = 0;

    for (int i = 0; i < imageSizes.length; i++) {
      final size = imageSizes[i];
      final scaledHeight = (size.height / size.width) * columnWidth + spacing;

      if (columnHeights[currentCol] + scaledHeight > usableHeight &&
          currentPage[currentCol].isNotEmpty) {
        currentCol++;
        if (currentCol >= numColumns) {
          pages.add(currentPage);
          currentPage = List.generate(numColumns, (_) => <int>[]);
          columnHeights = List.filled(numColumns, 0.0);
          currentCol = 0;
        }
      }

      currentPage[currentCol].add(i);
      columnHeights[currentCol] += scaledHeight;
    }

    if (currentPage.any((col) => col.isNotEmpty)) {
      pages.add(currentPage);
    }

    return pages;
  }

  Widget _buildA4Preview(Color primary, BoxConstraints constraints) {
    const a4Ratio = 210.0 / 297.0;
    const pageMargin = 12.0;
    const imageSpacing = 6.0;

    final pageWidth = constraints.maxWidth - 32;
    final pageHeight = pageWidth / a4Ratio;
    final numColumns = _twoColumns ? 2 : 1;
    final columnGap = _twoColumns ? 8.0 : 0.0;
    final columnWidth =
        (pageWidth - pageMargin * 2 - columnGap * (numColumns - 1)) / numColumns;
    final usableHeight = pageHeight - pageMargin * 2;

    final pages = _computeLayout(
      _imageSizes!,
      columnWidth,
      usableHeight,
      numColumns,
      imageSpacing,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: pages.asMap().entries.map((pageEntry) {
          final pageIdx = pageEntry.key;
          final page = pageEntry.value;

          return Column(
            children: [
              // 페이지 번호 표시 (2페이지 이상일 때)
              if (pages.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${pageIdx + 1} / ${pages.length} 페이지',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              // A4 페이지 카드
              Container(
                width: pageWidth,
                height: pageHeight,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(pageMargin),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(numColumns, (colIdx) {
                      final images =
                          colIdx < page.length ? page[colIdx] : <int>[];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: columnWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: images.map((imgIdx) {
                                final size = _imageSizes![imgIdx];
                                final scaledHeight =
                                    (size.height / size.width) * columnWidth;
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: imageSpacing),
                                  child: SizedBox(
                                    width: columnWidth,
                                    height: scaledHeight,
                                    child: Stack(
                                      children: [
                                        Image.memory(
                                          widget.crops[imgIdx],
                                          fit: BoxFit.contain,
                                          width: columnWidth,
                                          height: scaledHeight,
                                        ),
                                        Positioned(
                                          top: 3,
                                          left: 3,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: primary,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${imgIdx + 1}번',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          if (colIdx < numColumns - 1)
                            SizedBox(width: columnGap),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text('오답 모음 확인 (${widget.crops.length}개)'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
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
          // 정렬 선택 바
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: primary.withValues(alpha: 0.07),
            child: Row(
              children: [
                Text(
                  '정렬',
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 12),
                _ToggleButton(
                  label: '1열',
                  icon: Icons.view_agenda_outlined,
                  selected: !_twoColumns,
                  onTap: () => setState(() => _twoColumns = false),
                ),
                const SizedBox(width: 8),
                _ToggleButton(
                  label: '2열',
                  icon: Icons.grid_view,
                  selected: _twoColumns,
                  onTap: () => setState(() => _twoColumns = true),
                ),
              ],
            ),
          ),
          // A4 미리보기 영역
          Expanded(
            child: Container(
              color: Colors.grey[200],
              child: _imageSizes == null
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('이미지 로딩 중...',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) =>
                          _buildA4Preview(primary, constraints),
                    ),
            ),
          ),
          // PDF 생성 버튼
          SafeArea(
            top: false,
            child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isGenerating || _imageSizes == null)
                    ? null
                    : _generatePdf,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: Text(
                  _isGenerating ? 'PDF 생성 중...' : 'PDF 생성',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: primary.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: primary),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: selected ? Colors.white : primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
