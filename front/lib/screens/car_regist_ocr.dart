// lib/screens/car_regist_ocr.dart
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p; // 👈 BuildContext와 충돌 방지 (as p 로 사용)
import 'package:moring/providers/api_client.dart';
import 'package:moring/utils/custom_app_bar.dart';

/// 전역 카메라 리스트 (필요시 재사용)
List<CameraDescription>? _cameras;

class CarOcrRegistrationPage extends ConsumerStatefulWidget {
  const CarOcrRegistrationPage({Key? key}) : super(key: key);

  @override
  ConsumerState<CarOcrRegistrationPage> createState() => _CarOcrRegistrationPageState();
}

class _CarOcrRegistrationPageState extends ConsumerState<CarOcrRegistrationPage>
    with WidgetsBindingObserver {
  CameraController? _cameraController; // 👈 nullable
  bool _isCameraInitialized = false;
  bool _isTakingPicture = false;
  bool _isLoading = false;

  XFile? _capturedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 라이프사이클 관찰
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (_isCameraInitialized) return; // 중복 초기화 방지
    try {
      _cameras ??= await availableCameras();
      final CameraDescription first = _cameras!.first;

      final controller = CameraController(
        first,
        ResolutionPreset.low,                // 👈 버퍼 부담 줄이기 (필요하면 medium으로)
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420, // 👈 안정적인 포맷
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;
      setState(() => _isCameraInitialized = true);
    } catch (e, st) {
      debugPrint('Camera init error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카메라 초기화 실패')),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final c = _cameraController;
    if (c == null || !c.value.isInitialized) return;

    // 백그라운드로 가면 프리뷰를 멈춰 버퍼 반납 → 복귀 시 재개
    if (state == AppLifecycleState.inactive) {
      try {
        await c.pausePreview();
      } catch (_) {}
    } else if (state == AppLifecycleState.resumed) {
      try {
        await c.resumePreview();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    super.dispose();
  }

  Future<void> _disposeCamera() async {
    final c = _cameraController;
    _cameraController = null;
    _isCameraInitialized = false;

    if (c != null) {
      try {
        if (c.value.isStreamingImages) {
          await c.stopImageStream();
        }
        await c.dispose();
      } catch (_) {}
    }
  }

  Future<void> _takePicture(BuildContext context) async {
    final c = _cameraController;
    if (c == null || !c.value.isInitialized || _isTakingPicture) return;

    setState(() => _isTakingPicture = true);
    try {
      final image = await c.takePicture();
      if (!mounted) return;
      setState(() => _capturedImage = image);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진 촬영 실패')),
      );
    } finally {
      if (mounted) setState(() => _isTakingPicture = false);
    }
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() => _capturedImage = image);
    }
  }

  Future<Map<String, dynamic>> _sendOcrImage(XFile imageFile) async {
    final dio = ref.read(authDioProvider);
    debugPrint('[_sendOcrImage] 요청 시작: ${imageFile.path}');

    // MIME 타입 자동 감지
    final mimeType = lookupMimeType(imageFile.path) ?? 'application/octet-stream';
    final parts = mimeType.split('/');

    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: 'ocr_image${p.extension(imageFile.path)}', // 👈 p.extension 사용
        contentType: MediaType(parts.first, parts.length > 1 ? parts[1] : 'octet-stream'),
      ),
    });

    final response = await dio.post(
      '/api/v1/AI/car-registration',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    if (response.statusCode != 200 || response.data['isSuccess'] != true) {
      throw Exception(response.data['message'] ?? 'OCR 처리 실패');
    }

    final result = Map<String, dynamic>.from(response.data['result'] ?? {});
    debugPrint('[_sendOcrImage] 성공. result: $result');
    return result;
  }

  Future<void> _onRegister(BuildContext context) async {
    if (_isLoading) return;
    if (_capturedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지를 먼저 촬영 또는 선택하세요.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final ocrResult = await _sendOcrImage(_capturedImage!);
      if (!mounted) return;
      setState(() => _isLoading = false);
      // OCR 결과를 이전 화면으로 전달
      Navigator.pop(context, ocrResult);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('[_onRegister] 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR 요청 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraBoxColor = const Color(0xFF353A41);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'OCR 등록',
        onBackButtonPressed: () => Navigator.pop(context),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 미리보기/결과 영역
            Container(
              width: double.infinity,
              height: 400,
              decoration: BoxDecoration(
                color: cameraBoxColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _capturedImage != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_capturedImage!.path),
                  fit: BoxFit.cover,
                ),
              )
                  : (_isCameraInitialized && _cameraController != null)
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CameraPreview(_cameraController!),
              )
                  : const Center(child: CircularProgressIndicator()),
            ),
            const SizedBox(height: 20),

            // 버튼들
            if (_capturedImage == null) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isTakingPicture ? null : () => _takePicture(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: _isTakingPicture
                      ? const SizedBox(
                    width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Text('카메라로 촬영하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _pickImageFromGallery,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white38),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('갤러리에서 선택하기', style: TextStyle(fontSize: 16)),
                ),
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: '다시 촬영',
                    icon: const Icon(Icons.refresh, size: 48),
                    onPressed: () => setState(() => _capturedImage = null),
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    tooltip: 'OCR 등록',
                    icon: _isLoading
                        ? const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                        : const Icon(Icons.check_circle, size: 48, color: Colors.green),
                    onPressed: _isLoading ? null : () => _onRegister(context),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
