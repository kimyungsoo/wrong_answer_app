import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ReplicateService {
  static const String _serverUrl = 'https://wronganswerapp.com';

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

    request.headers.addAll({
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
      'Accept': 'image/jpeg, */*',
    });

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      imageBytes,
      filename: 'image.jpg',
      contentType: MediaType('image', 'jpeg'),
    ));

    onStatus?.call('필기 제거 중...');

    try {
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 120),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        onStatus?.call('완료');
        return response.bodyBytes;
      } else {
        final body = response.body.length > 200
            ? response.body.substring(0, 200)
            : response.body;
        throw Exception('HTTP ${response.statusCode}: $body');
      }
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('연결 실패: $e');
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
