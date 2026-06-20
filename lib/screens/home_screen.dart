import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../models/crop_area.dart';
import 'crop_screen.dart';
import 'preview_screen.dart';
import 'collection_screen.dart';
import 'saved_notes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<Uint8List> _accumulatedCrops = [];

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null && mounted) {
      _navigateToCropScreen(photo);
    }
  }

  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      _navigateToCropScreen(image);
    }
  }

  void _navigateToCropScreen(XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    if (!mounted) return;

    final result = await Navigator.of(context).push<(List<CropArea>, Size)>(
      MaterialPageRoute(
        builder: (context) => CropScreen(
          imageBytes: bytes,
          startIndex: _accumulatedCrops.length,
        ),
      ),
    );

    if (!mounted) return;
    if (result != null && result.$1.isNotEmpty) {
      await _processCroppedImages(bytes, result.$1, result.$2);
    }
  }

  Future<void> _processCroppedImages(
    Uint8List imageBytes,
    List<CropArea> cropAreas,
    Size containerSize,
  ) async {
    final newCrops = await Navigator.of(context).push<List<Uint8List>>(
      MaterialPageRoute(
        builder: (context) => PreviewScreen(
          imageBytes: imageBytes,
          cropAreas: cropAreas,
          containerSize: containerSize,
          startIndex: _accumulatedCrops.length,
        ),
      ),
    );

    if (!mounted) return;
    if (newCrops != null && newCrops.isNotEmpty) {
      setState(() {
        _accumulatedCrops.addAll(newCrops);
      });
    }
  }

  void _openCollection() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CollectionScreen(crops: List.from(_accumulatedCrops)),
      ),
    );
  }

  void _openSavedNotes() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SavedNotesScreen()),
    );
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('초기화'),
        content: const Text('모은 오답을 모두 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _accumulatedCrops.clear());
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '오답 모음집',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 누적 오답 현황 카드
            if (_accumulatedCrops.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primary, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.collections_bookmark, color: primary, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            '모은 오답: ${_accumulatedCrops.length}개',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primary,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _clearAll,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                            ),
                            child: const Text('초기화'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openCollection,
                          icon: const Icon(Icons.collections_bookmark),
                          label: const Text(
                            '오답 모음 확인',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            SizedBox(height: _accumulatedCrops.isEmpty
                ? MediaQuery.of(context).size.height * 0.12
                : 24),

            // 아이콘
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: 0.1),
                ),
                child: Icon(Icons.collections_bookmark, size: 50, color: primary),
              ),
            ),
            const SizedBox(height: 24),

            // 안내 텍스트
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    _accumulatedCrops.isEmpty
                        ? '틀린 문제를 모아서\nA4 PDF로 만들어보세요'
                        : '사진을 더 추가하거나\nPDF를 생성하세요',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '문제집 사진을 찍거나 갤러리에서 선택한 후,\n틀린 문제 부분을 드래그로 표시하세요',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),

            SizedBox(height: _accumulatedCrops.isEmpty
                ? MediaQuery.of(context).size.height * 0.08
                : 24),

            // 카메라 / 갤러리 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.camera_alt,
                      label: '카메라\n촬영',
                      onPressed: _takePhoto,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.image,
                      label: '갤러리\n선택',
                      onPressed: _pickFromGallery,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 만든 오답노트 보기 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextButton.icon(
                onPressed: _openSavedNotes,
                icon: Icon(Icons.folder_open, color: Colors.grey[600]),
                label: Text(
                  '만든 오답노트 보기',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
