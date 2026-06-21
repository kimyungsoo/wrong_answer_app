import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ReplicateService {
  static const String _serverUrl = 'http://192.168.0.192:8080';

  static bool get isConfigured => true;

  static Future<Uint8List> removeHandwriting(
    Uint8List imageBytes, {
    void Function(String status)? onStatus,
  }) async {
    onStatus?.call('서버 연결 중...');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_serverUrl/remove-handwriting'),
    );
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      imageBytes,
      filename: 'image.jpg',
    ));

    onStatus?.call('필기 제거 중...');
    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
    );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      onStatus?.call('완료');
      return response.bodyBytes;
    } else {
      throw Exception('서버 오류: ${response.statusCode}');
    }
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
      final result = await removeHandwriting(
        images[i],
        onStatus: (s) => onProgress?.call(i + 1, images.length, s),
      );
      results.add(result);
    }
    return results;
  }
}
