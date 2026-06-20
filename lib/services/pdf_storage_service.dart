import 'dart:typed_data';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'pdf_file_io.dart' if (dart.library.html) 'pdf_file_web.dart';

class SavedPdf {
  final String id;
  final String title;
  final DateTime savedAt;
  final int cropCount;
  final bool twoColumns;
  final bool handwritingRemoved;

  SavedPdf({
    required this.id,
    required this.title,
    required this.savedAt,
    this.cropCount = 0,
    this.twoColumns = false,
    this.handwritingRemoved = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'savedAt': savedAt.toIso8601String(),
        'cropCount': cropCount,
        'twoColumns': twoColumns,
        'handwritingRemoved': handwritingRemoved,
      };

  factory SavedPdf.fromJson(Map<String, dynamic> json) => SavedPdf(
        id: json['id'],
        title: json['title'],
        savedAt: DateTime.parse(json['savedAt']),
        cropCount: json['cropCount'] ?? 0,
        twoColumns: json['twoColumns'] ?? false,
        handwritingRemoved: json['handwritingRemoved'] ?? false,
      );
}

class PdfStorageService {
  static const _prefsKey = 'saved_pdfs_v1';

  static Future<void> save(
    String title,
    Uint8List pdfBytes, {
    List<Uint8List>? crops,
    bool twoColumns = false,
    bool handwritingRemoved = false,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await savePdfFile(id, pdfBytes);

    if (crops != null && crops.isNotEmpty) {
      await saveCropImages(id, crops);
    }

    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? [];
    list.add(jsonEncode(SavedPdf(
      id: id,
      title: title,
      savedAt: DateTime.now(),
      cropCount: crops?.length ?? 0,
      twoColumns: twoColumns,
      handwritingRemoved: handwritingRemoved,
    ).toJson()));
    await prefs.setStringList(_prefsKey, list);
  }

  static Future<List<SavedPdf>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? [];
    final pdfs = list.map((s) {
      try {
        return SavedPdf.fromJson(jsonDecode(s));
      } catch (_) {
        return null;
      }
    }).whereType<SavedPdf>().toList();
    pdfs.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return pdfs;
  }

  static Future<Uint8List?> loadBytes(String id) => loadPdfFile(id);

  static Future<List<Uint8List>?> loadCrops(String id, int count) =>
      loadCropImages(id, count);

  static Future<void> delete(SavedPdf pdf) async {
    await deletePdfFile(pdf.id);
    await deleteCropImages(pdf.id);
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? [];
    list.removeWhere((s) {
      try {
        return SavedPdf.fromJson(jsonDecode(s)).id == pdf.id;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_prefsKey, list);
  }
}
