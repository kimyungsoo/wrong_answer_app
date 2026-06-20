import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'pdf_service.dart';

class PdfGenerator {
  /// 1열 PDF 생성
  static Future<Uint8List> generatePdf(
    List<List<CroppedImage>> pages,
  ) async {
    final pdf = pw.Document();

    for (final pageImages in pages) {
      final widgets = <pw.Widget>[];

      for (final image in pageImages) {
        final pdfImage = pw.MemoryImage(image.imageData);
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

  /// 다열 PDF 생성
  static Future<Uint8List> generatePdfColumns(
    List<List<List<CroppedImage>>> pages,
    int numColumns,
  ) async {
    final pdf = pw.Document();
    final columnGapPt = PdfService.spacing * PdfService.mmToPt;
    final columnWidth =
        (PdfService.useableWidth - (numColumns - 1) * columnGapPt) / numColumns;
    final spacingPt = PdfService.spacing * PdfService.mmToPt;

    for (final pageColumns in pages) {
      final rowChildren = <pw.Widget>[];

      for (int colIdx = 0; colIdx < numColumns; colIdx++) {
        final images = colIdx < pageColumns.length ? pageColumns[colIdx] : <CroppedImage>[];
        final colWidgets = images.map((image) {
          final pdfImage = pw.MemoryImage(image.imageData);
          final scaledHeight = (columnWidth / image.width) * image.height;
          return pw.Container(
            margin: pw.EdgeInsets.only(bottom: spacingPt),
            child: pw.Image(
              pdfImage,
              width: columnWidth,
              height: scaledHeight,
              fit: pw.BoxFit.fill,
            ),
          );
        }).toList();

        rowChildren.add(
          pw.SizedBox(
            width: columnWidth,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: colWidgets,
            ),
          ),
        );

        if (colIdx < numColumns - 1) {
          rowChildren.add(pw.SizedBox(width: columnGapPt));
        }
      }

      pdf.addPage(
        pw.Page(
          margin: pw.EdgeInsets.all(PdfService.marginLeft * PdfService.mmToPt),
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: rowChildren,
          ),
        ),
      );
    }

    return pdf.save();
  }
}
