import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:image/image.dart' as img;
import '../services/pdf_storage_service.dart';
import '../services/replicate_service.dart';
import '../services/pdf_service.dart';
import '../services/pdf_generator.dart';
import 'pdf_viewer_screen.dart';

List<Map<String, double>> _computeImageSizes(List<Uint8List> imageBytesList) {
  return imageBytesList.map((bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded != null) {
      return {'w': decoded.width.toDouble(), 'h': decoded.height.toDouble()};
    }
    return {'w': 100.0, 'h': 100.0};
  }).toList();
}

class SavedNotesScreen extends StatefulWidget {
  const SavedNotesScreen({super.key});

  @override
  State<SavedNotesScreen> createState() => _SavedNotesScreenState();
}

class _SavedNotesScreenState extends State<SavedNotesScreen> {
  late Future<List<SavedPdf>> _savedPdfs;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _savedPdfs = PdfStorageService.loadAll();
    });
  }

  Future<void> _openPdf(SavedPdf pdf) async {
    final messenger = ScaffoldMessenger.of(context);
    final bytes = await PdfStorageService.loadBytes(pdf.id);
    if (bytes == null) {
      messenger.showSnackBar(const SnackBar(content: Text('파일을 찾을 수 없습니다')));
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(pdfBytes: bytes, title: pdf.title),
      ),
    );
  }

  Future<void> _deletePdf(SavedPdf pdf) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제'),
        content: Text('"${pdf.title}"을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await PdfStorageService.delete(pdf);
      _reload();
    }
  }

  Future<void> _removeHandwriting(SavedPdf pdf) async {
    // crop 이미지 존재 확인
    if (pdf.cropCount == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이 PDF는 원본 이미지가 저장되지 않아 처리할 수 없습니다')),
      );
      return;
    }

    // 처리 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('필기 제거'),
        content: Text(
          '"${pdf.title}"\n\n'
          '${pdf.cropCount}개 이미지에서 연필 필기를 제거하고\n'
          '새 PDF를 생성합니다.\n\n'
          '이미지당 약 20~40초 소요됩니다.\n'
          '(예상 시간: ${(pdf.cropCount * 30 / 60).ceil()}분)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('시작'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // 진행 다이얼로그 표시
    bool cancelled = false;
    String progressText = '이미지 로드 중...';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('필기 제거 중'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(progressText),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  cancelled = true;
                  Navigator.pop(context);
                },
                child: const Text('취소'),
              ),
            ],
          );
        },
      ),
    );

    final messenger = ScaffoldMessenger.of(context);

    try {
      // crop 이미지 로드
      final crops = await PdfStorageService.loadCrops(pdf.id, pdf.cropCount);
      if (crops == null || crops.isEmpty || !mounted) {
        if (mounted) Navigator.of(context).pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('원본 이미지를 불러올 수 없습니다')),
        );
        return;
      }

      // Replicate API로 필기 제거
      final cleanedCrops = await ReplicateService.removeHandwritingBatch(
        crops,
        onProgress: (current, total, status) {
          progressText = '이미지 처리 중... ($current / $total)\n$status';
        },
        isCancelled: () => cancelled,
      );

      if (cancelled || !mounted) return;

      if (mounted) Navigator.of(context).pop();

      // 새 PDF 생성
      final newTitle = '${pdf.title}_필기제거';
      final sizeData = await compute(_computeImageSizes, cleanedCrops);
      final croppedImageObjects = <CroppedImage>[];
      for (int i = 0; i < cleanedCrops.length; i++) {
        croppedImageObjects.add(CroppedImage(
          imageData: cleanedCrops[i],
          width: sizeData[i]['w']!,
          height: sizeData[i]['h']!,
        ));
      }

      final Uint8List newPdfBytes;
      if (pdf.twoColumns) {
        final pages = PdfService.arrangeImagesOnPagesColumns(croppedImageObjects, 2);
        newPdfBytes = await PdfGenerator.generatePdfColumns(pages, 2);
      } else {
        final pages = PdfService.arrangeImagesOnPages(croppedImageObjects);
        newPdfBytes = await PdfGenerator.generatePdf(pages);
      }

      await PdfStorageService.save(
        newTitle,
        newPdfBytes,
        crops: cleanedCrops,
        twoColumns: pdf.twoColumns,
        handwritingRemoved: true,
      );

      _reload();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$newTitle" 저장 완료!')),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text('처리 실패: $e')));
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('만든 오답노트'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<SavedPdf>>(
        future: _savedPdfs,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final pdfs = snapshot.data ?? [];

          if (pdfs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.picture_as_pdf_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    '저장된 오답노트가 없어요',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PDF를 생성하면 여기에 목록이 나타납니다',
                    style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pdfs.length,
            itemBuilder: (context, index) {
              final pdf = pdfs[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.picture_as_pdf, color: primary, size: 28),
                  ),
                  title: Text(
                    pdf.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _formatDate(pdf.savedAt),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (pdf.cropCount > 0 && !pdf.handwritingRemoved)
                        IconButton(
                          icon: const Icon(Icons.auto_fix_high),
                          color: Colors.orange[700],
                          onPressed: () => _removeHandwriting(pdf),
                          tooltip: '필기 제거',
                        ),
                      IconButton(
                        icon: Icon(Icons.open_in_new, color: primary),
                        onPressed: () => _openPdf(pdf),
                        tooltip: '열기',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deletePdf(pdf),
                        tooltip: '삭제',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
