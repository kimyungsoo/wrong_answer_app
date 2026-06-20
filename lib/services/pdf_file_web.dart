import 'dart:typed_data';

// Web에서는 파일 시스템 저장 불가 — 메모리 캐시만 사용
final Map<String, Uint8List> _cache = {};
final Map<String, List<Uint8List>> _cropCache = {};

Future<void> savePdfFile(String id, Uint8List bytes) async {
  _cache[id] = bytes;
}

Future<Uint8List?> loadPdfFile(String id) async => _cache[id];

Future<void> deletePdfFile(String id) async {
  _cache.remove(id);
}

Future<void> saveCropImages(String id, List<Uint8List> crops) async {
  _cropCache[id] = crops;
}

Future<List<Uint8List>?> loadCropImages(String id, int count) async => _cropCache[id];

Future<void> deleteCropImages(String id) async {
  _cropCache.remove(id);
}
