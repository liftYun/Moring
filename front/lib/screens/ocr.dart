import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:moring/utils/custom_app_bar.dart';

List<CameraDescription>? cameras;

class OcrRegistrationPage extends StatefulWidget {
  const OcrRegistrationPage({Key? key}) : super(key: key);

  @override
  State<OcrRegistrationPage> createState() => _OcrRegistrationPageState();
}

class _OcrRegistrationPageState extends State<OcrRegistrationPage> {
  late CameraController _cameraController;
  bool _isCameraInitialized = false;
  XFile? _capturedImage;
  bool _isTakingPicture = false;

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    cameras = await availableCameras();
    final firstCamera = cameras!.first;

    _cameraController = CameraController(
      firstCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

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

  Future<void> _takePicture() async {
    if (!_cameraController.value.isInitialized || _isTakingPicture) return;

    setState(() {
      _isTakingPicture = true;
    });

    try {
      final image = await _cameraController.takePicture();
      if (!mounted) return;
      setState(() {
        _capturedImage = image;
      });
    } catch (e) {
      debugPrint('Error taking picture: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진 촬영에 실패했습니다. 다시 시도해 주세요.')),
      );
    } finally {
      setState(() {
        _isTakingPicture = false;
      });
    }
  }

  void _onRegister() {
    // TODO: 사진 파일(_capturedImage!.path) 서버 업로드 또는 OCR 등 원하는 처리
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('등록 로직을 구현하세요.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cameraBoxColor = const Color(0xFF353A41);

    return Scaffold(
      appBar: CustomAppBar(
        title: '차량 등록',
        onBackButtonPressed: () => Navigator.pop(context),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 미리보기 또는 카메라 프리뷰
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
                  width: double.infinity,
                  height: 400,
                  fit: BoxFit.cover,
                ),
              )
                  : _isCameraInitialized
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CameraPreview(_cameraController),
              )
                  : const Center(child: CircularProgressIndicator()),
            ),
            const SizedBox(height: 30),

            // 버튼/아이콘 UI
            if (_capturedImage == null)
            // 처음엔 '등록하기' 텍스트 버튼
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isTakingPicture ? null : _takePicture,
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
                    '등록하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else
            // 촬영 후: 체크(등록)/재촬영 아이콘 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white70, size: 48),
                    onPressed: () {
                      setState(() {
                        _capturedImage = null;
                      });
                    },
                    tooltip: '다시 찍기',
                  ),
                  const SizedBox(width: 32),
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
                    onPressed: _onRegister, // "이 사진으로 등록"
                    tooltip: '등록',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
