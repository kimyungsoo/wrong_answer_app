import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class PdfViewerScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String title;

  const PdfViewerScreen({
    super.key,
    required this.pdfBytes,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: '인쇄',
            onPressed: () => Printing.layoutPdf(
              onLayout: (_) async => pdfBytes,
              name: title,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: '공유',
            onPressed: () => Printing.sharePdf(
              bytes: pdfBytes,
              filename: '$title.pdf',
            ),
          ),
        ],
      ),
      body: PdfPreview(
        build: (_) async => pdfBytes,
        canChangePageFormat: false,
        canChangeOrientation: false,
        allowPrinting: false,
        allowSharing: false,
        initialPageFormat: PdfPageFormat.a4,
      ),
    );
  }
}
