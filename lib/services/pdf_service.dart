import 'dart:typed_data';
import 'dart:io';
import 'package:image/image.dart' as img;

class CroppedImage {
  final Uint8List imageData;
  final double width;
  final double height;

  CroppedImage({
    required this.imageData,
    required this.width,
    required this.height,
  });

  double get aspectRatio => width / height;
}

class PdfService {
  // A4 크기 (mm to points: 1mm = 2.834645669 points)
  static const double a4Width = 210; // mm
  static const double a4Height = 297; // mm
  static const double mmToPt = 2.834645669;

  // A4 페이지를 포인트 단위로 변환
  static double get pageWidth => a4Width * mmToPt;
  static double get pageHeight => a4Height * mmToPt;

  // 여백 설정 (mm)
  static const double marginTop = 10;
  static const double marginBottom = 10;
  static const double marginLeft = 10;
  static const double marginRight = 10;
  static const double spacing = 5; // 이미지 간 간격

  // 사용 가능한 영역
  static double get useableWidth =>
      (a4Width - marginLeft - marginRight) * mmToPt;
  static double get useableHeight =>
      (a4Height - marginTop - marginBottom) * mmToPt;

  /// 원본 이미지에서 크롭 영역만 추출
  static Future<CroppedImage> extractCroppedImage(
    String imagePath,
    double startX,
    double startY,
    double endX,
    double endY,
  ) async {
    final bytes = await File(imagePath).readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) throw Exception('이미지를 로드할 수 없습니다');

    // 크롭 좌표 정규화
    final left = startX < endX ? startX.toInt() : endX.toInt();
    final top = startY < endY ? startY.toInt() : endY.toInt();
    final right = startX < endX ? endX.toInt() : startX.toInt();
    final bottom = startY < endY ? endY.toInt() : startY.toInt();

    final width = right - left;
    final height = bottom - top;

    if (width <= 0 || height <= 0) {
      throw Exception('유효하지 않은 크롭 영역입니다');
    }

    // 이미지 크롭
    final croppedImg = img.copyCrop(
      image,
      x: left,
      y: top,
      width: width,
      height: height,
    );

    return CroppedImage(
      imageData: Uint8List.fromList(img.encodeJpg(croppedImg, quality: 90)),
      width: width.toDouble(),
      height: height.toDouble(),
    );
  }

  /// A4 페이지에 이미지들을 자동 배치 (1열)
  static List<List<CroppedImage>> arrangeImagesOnPages(
    List<CroppedImage> images,
  ) {
    final pages = <List<CroppedImage>>[];
    final currentPage = <CroppedImage>[];
    double currentY = 0;

    for (final image in images) {
      final scaledHeight = (useableWidth / image.width) * image.height;
      final totalHeight = scaledHeight + spacing;

      if (currentY + totalHeight > useableHeight && currentPage.isNotEmpty) {
        pages.add(List.from(currentPage));
        currentPage.clear();
        currentY = 0;
      }

      currentPage.add(image);
      currentY += totalHeight;
    }

    if (currentPage.isNotEmpty) {
      pages.add(currentPage);
    }

    return pages;
  }

  /// A4 페이지에 이미지들을 다열로 자동 배치
  /// 반환: [ page[ column[ image ] ] ]
  static List<List<List<CroppedImage>>> arrangeImagesOnPagesColumns(
    List<CroppedImage> images,
    int numColumns,
  ) {
    final columnGapPt = spacing * mmToPt;
    final columnWidth =
        (useableWidth - (numColumns - 1) * columnGapPt) / numColumns;
    final usableHeightPt = useableHeight;

    final pages = <List<List<CroppedImage>>>[];
    var currentPage = List.generate(numColumns, (_) => <CroppedImage>[]);
    var columnHeights = List.filled(numColumns, 0.0);
    var currentCol = 0;

    for (final image in images) {
      final scaledHeight = (columnWidth / image.width) * image.height;
      final totalHeight = scaledHeight + spacing * mmToPt;

      if (columnHeights[currentCol] + totalHeight > usableHeightPt &&
          currentPage[currentCol].isNotEmpty) {
        currentCol++;
        if (currentCol >= numColumns) {
          pages.add(currentPage);
          currentPage = List.generate(numColumns, (_) => <CroppedImage>[]);
          columnHeights = List.filled(numColumns, 0.0);
          currentCol = 0;
        }
      }

      currentPage[currentCol].add(image);
      columnHeights[currentCol] += totalHeight;
    }

    if (currentPage.any((col) => col.isNotEmpty)) {
      pages.add(currentPage);
    }

    return pages;
  }
}
