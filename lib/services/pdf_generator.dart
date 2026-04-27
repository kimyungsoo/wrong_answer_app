import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../services/pdf_service.dart';

class PdfGenerator {
  /// 크롭된 이미지들로부터 PDF 생성
  static Future<Uint8List> generatePdf(
    List<List<PdfService.CroppedImage>> pages,
  ) async {
    final pdf = pw.Document();

    for (final pageImages in pages) {
      final widgets = <pw.Widget>[];

      for (final image in pageImages) {
        // 이미지 데이터로부터 PDF 이미지 생성
        final pdfImage = pw.MemoryImage(image.imageData);

        // 이미지 높이 계산 (A4 너비에 맞춰서)
        final scaledHeight =
            (PdfService.useableWidth / image.width) * image.height;

        widgets.add(
          pw.Container(
            margin: pw.EdgeInsets.only(
              bottom: PdfService.spacing * PdfService.mmToPt,
            ),
            child: pw.Image(
              pdfImage,
              width: PdfService.useableWidth,
              height: scaledHeight,
              fit: pw.BoxFit.fill,
            ),
          ),
        );
      }

      // 페이지 추가
      pdf.addPage(
        pw.Page(
          margin: pw.EdgeInsets.all(PdfService.marginLeft * PdfService.mmToPt),
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: widgets,
          ),
        ),
      );
    }

    return pdf.save();
  }
}
