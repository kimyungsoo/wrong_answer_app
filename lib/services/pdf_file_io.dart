import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<void> savePdfFile(String id, Uint8List bytes) async {
  final dir = await getApplicationDocumentsDirectory();
  final pdfsDir = Directory('${dir.path}/pdfs');
  if (!await pdfsDir.exists()) await pdfsDir.create(recursive: true);
  await File('${pdfsDir.path}/$id.pdf').writeAsBytes(bytes);
}

Future<Uint8List?> loadPdfFile(String id) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/pdfs/$id.pdf');
  if (await file.exists()) return await file.readAsBytes();
  return null;
}

Future<void> deletePdfFile(String id) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/pdfs/$id.pdf');
  if (await file.exists()) await file.delete();
}

Future<void> saveCropImages(String id, List<Uint8List> crops) async {
  final dir = await getApplicationDocumentsDirectory();
  final cropsDir = Directory('${dir.path}/pdfs/crops_$id');
  if (!await cropsDir.exists()) await cropsDir.create(recursive: true);
  for (int i = 0; i < crops.length; i++) {
    await File('${cropsDir.path}/$i.jpg').writeAsBytes(crops[i]);
  }
}

Future<List<Uint8List>?> loadCropImages(String id, int count) async {
  final dir = await getApplicationDocumentsDirectory();
  final cropsDir = Directory('${dir.path}/pdfs/crops_$id');
  if (!await cropsDir.exists()) return null;
  final results = <Uint8List>[];
  for (int i = 0; i < count; i++) {
    final file = File('${cropsDir.path}/$i.jpg');
    if (await file.exists()) results.add(await file.readAsBytes());
  }
  return results.isEmpty ? null : results;
}

Future<void> deleteCropImages(String id) async {
  final dir = await getApplicationDocumentsDirectory();
  final cropsDir = Directory('${dir.path}/pdfs/crops_$id');
  if (await cropsDir.exists()) await cropsDir.delete(recursive: true);
}
