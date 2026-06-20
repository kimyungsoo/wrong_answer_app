import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

Uint8List _processRemoveHandwriting(Uint8List imageBytes) {
  final decoded = img.decodeImage(imageBytes);
  if (decoded == null) return imageBytes;

  final maxVal = decoded.maxChannelValue;
  final threshold = maxVal * 0.78; // 연필 자국(밝은 회색) 제거 임계값

  for (final pixel in decoded) {
    final luminance = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
    if (luminance > threshold) {
      decoded.setPixelRgb(pixel.x, pixel.y, maxVal, maxVal, maxVal);
    }
  }

  return Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
}

class ReplicateService {
  static bool get isConfigured => true;

  static Future<Uint8List> removeHandwriting(
    Uint8List imageBytes, {
    void Function(String status)? onStatus,
  }) async {
    onStatus?.call('처리 중...');
    return compute(_processRemoveHandwriting, imageBytes);
  }

  static Future<List<Uint8List>> removeHandwritingBatch(
    List<Uint8List> images, {
    void Function(int current, int total, String status)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final results = <Uint8List>[];
    for (int i = 0; i < images.length; i++) {
      if (isCancelled?.call() == true) {
        results.addAll(images.sublist(i));
        break;
      }
      onProgress?.call(i + 1, images.length, '처리 중...');
      final result = await removeHandwriting(
        images[i],
        onStatus: (s) => onProgress?.call(i + 1, images.length, s),
      );
      results.add(result);
    }
    return results;
  }
}
