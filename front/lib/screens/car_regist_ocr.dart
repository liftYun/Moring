import 'dart:io';
import 'package:path/path.dart';
import 'package:mime/mime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moring/utils/custom_app_bar.dart';
import 'package:moring/providers/api_client.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

List<CameraDescription>? cameras;

class CarOcrRegistrationPage extends ConsumerStatefulWidget {
  const CarOcrRegistrationPage({Key? key}) : super(key: key);

  @override
  ConsumerState<CarOcrRegistrationPage> createState() => _CarOcrRegistrationPageState();
}

class _CarOcrRegistrationPageState extends ConsumerState<CarOcrRegistrationPage> {
  late CameraController _cameraController;
  bool _isCameraInitialized = false;
  XFile? _capturedImage;
  bool _isTakingPicture = false;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    cameras = await availableCameras();
    final firstCamera = cameras!.first;

    _cameraController = CameraController(firstCamera, ResolutionPreset.medium, enableAudio: false);
    await _cameraController.initialize();

    if (!mounted) return;
    setState(() {
      _isCameraInitialized = true;
      _capturedImage = null;
    });
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  // context를 매개변수로 받도록 수정
  Future<void> _takePicture(BuildContext context) async {
    if (!_cameraController.value.isInitialized || _isTakingPicture) return;
    setState(() => _isTakingPicture = true);

    try {
      final image = await _cameraController.takePicture();
      if (!mounted) return;
      setState(() => _capturedImage = image);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진 촬영 실패')),
      );
    } finally {
      setState(() => _isTakingPicture = false);
    }
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _capturedImage = image);
    }
  }

  Future<Map<String, dynamic>> _sendOcrImage(XFile imageFile) async {
    final dio = ref.read(authDioProvider);
    print('[_sendOcrImage] 함수 실행됨. API 요청 시작.');

    // MIME 타입 자동 감지
    final mimeType = lookupMimeType(imageFile.path) ?? 'application/octet-stream';
    final mimeParts = mimeType.split('/');

    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: 'ocr_image${extension(imageFile.path)}',
        contentType: MediaType(mimeParts[0], mimeParts[1]),
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

    print('[_sendOcrImage] API 응답 데이터: ${response.data}');
    print('[_sendOcrImage] 추출된 result 값: ${response.data['result']}');
    return Map<String, dynamic>.from(response.data['result'] ?? {});
  }

  // context를 매개변수로 받도록 수정
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
      Navigator.pop(context, ocrResult); // 결과를 이전 페이지로 반환
    } catch (e) {
      setState(() => _isLoading = false);
      print('[_onRegister] 오류 발생: $e');
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
            // 미리보기 영역
            Container(
              width: double.infinity,
              height: 400,
              decoration: BoxDecoration(color: cameraBoxColor, borderRadius: BorderRadius.circular(12)),
              child: _capturedImage != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(_capturedImage!.path), fit: BoxFit.cover),
              )
                  : _isCameraInitialized
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CameraPreview(_cameraController),
              )
                  : const Center(child: CircularProgressIndicator()),
            ),
            const SizedBox(height: 20),

            if (_capturedImage == null)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isTakingPicture ? null : () => _takePicture(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: _isTakingPicture
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                        '카메라로 촬영하기',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '갤러리에서 선택하기',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 48),
                    onPressed: () => setState(() {
                      _capturedImage = null;
                    }),
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    icon: _isLoading
                        ? const CircularProgressIndicator()
                        : const Icon(Icons.check_circle, size: 48, color: Colors.green),
                    onPressed: _isLoading ? null : () => _onRegister(context),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}