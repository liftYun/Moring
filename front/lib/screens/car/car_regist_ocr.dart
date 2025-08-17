import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:mime/mime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moring/utils/custom_app_bar.dart';
import 'package:moring/providers/api_client.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

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

  Future<bool> _requestPermission(Permission permission) async {
    final status = await permission.request();
    return status.isGranted;
  }

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

  Future<bool> _requestCameraPermissionWithCustomUI(BuildContext context) async {
    final status = await Permission.camera.status;

    if (status.isGranted) {
      return true;
    }

    final bool? userAgreed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('카메라 권한 요청'),
          content: const Text('OCR 기능을 사용하려면 카메라 접근 권한이 필요합니다. 사진을 촬영하여 차량 정보를 자동으로 등록할 수 있습니다.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );

    if (userAgreed == true) {
      final permissionStatus = await Permission.camera.request();
      return permissionStatus.isGranted;
    }

    return false;
  }

  Future<void> _takePicture(BuildContext context) async {
    final hasPermission = await _requestCameraPermissionWithCustomUI(context);

    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카메라 권한이 허용되지 않았습니다.')),
      );
      return;
    }

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
    print('[_pickImageFromGallery] 함수 호출됨');
    
    // 권한 요청
    final hasPermission = await _requestPermission(Permission.photos);
    print('[_pickImageFromGallery] 권한 상태: $hasPermission');
    
    if (!hasPermission) {
      print('[_pickImageFromGallery] 권한이 거부됨');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('갤러리 접근 권한이 필요합니다.')),
      );
      return;
    }

    try {
      // 갤러리에서 이미지 선택
      print('[_pickImageFromGallery] 갤러리에서 이미지 선택 시작');
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        print('[_pickImageFromGallery] 이미지 선택됨: ${image.path}');
        setState(() => _capturedImage = image);
      } else {
        print('[_pickImageFromGallery] 이미지 선택 취소됨');
      }
    } catch (e) {
      print('[_pickImageFromGallery] 오류 발생: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다: $e')),
      );
    }
  }

  Future<Map<String, dynamic>> _sendOcrImage(XFile imageFile) async {
    final dio = ref.read(authDioProvider);
    print('[_sendOcrImage] 함수 실행됨. API 요청 시작.');

    try {
      final Uint8List? compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.path,
        quality: 50,
      );

      if (compressedBytes == null) {
        throw Exception('이미지 압축에 실패했습니다.');
      }

      print('[_sendOcrImage] 원본 이미지 크기: ${await imageFile.length()} bytes');
      print('[_sendOcrImage] 압축된 이미지 크기: ${compressedBytes.length} bytes');

      final mimeType = lookupMimeType(imageFile.path) ?? 'application/octet-stream';
      final mimeParts = mimeType.split('/');

      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          compressedBytes,
          filename: 'ocr_image${p.extension(imageFile.path)}',
          contentType: MediaType(mimeParts[0], mimeParts[1]),
        ),
      });

      print('[_sendOcrImage] API 요청 시작: /api/v1/AI/car-registration');
      print('[_sendOcrImage] FormData 크기: ${formData.length} bytes');

      final response = await dio.post(
        '/api/v1/AI/car-registration',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      print('[_sendOcrImage] API 응답 상태 코드: ${response.statusCode}');
      print('[_sendOcrImage] API 응답 헤더: ${response.headers}');
      print('[_sendOcrImage] API 응답 데이터: ${response.data}');

      if (response.statusCode != 200) {
        throw Exception('서버 오류: ${response.statusCode} - ${response.statusMessage}');
      }

      if (response.data['isSuccess'] != true) {
        final errorMessage = response.data['message'] ?? 'OCR 처리 실패';
        print('[_sendOcrImage] OCR 처리 실패: $errorMessage');
        throw Exception(errorMessage);
      }

      final result = response.data['result'];
      print('[_sendOcrImage] 추출된 result 값: $result');
      
      if (result == null) {
        throw Exception('OCR 결과가 비어있습니다.');
      }

      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('[_sendOcrImage] 예외 발생: $e');
      if (e is DioException) {
        print('[_sendOcrImage] DioException 상세 정보:');
        print('  - Type: ${e.type}');
        print('  - Message: ${e.message}');
        print('  - Error: ${e.error}');
        print('  - Response: ${e.response?.data}');
        print('  - Status Code: ${e.response?.statusCode}');
        
        if (e.response?.statusCode == 500) {
          throw Exception('서버 내부 오류 (500): 서버에서 OCR 처리 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요.');
        } else if (e.type == DioExceptionType.connectionTimeout) {
          throw Exception('연결 시간 초과: 네트워크 연결을 확인해주세요.');
        } else if (e.type == DioExceptionType.receiveTimeout) {
          throw Exception('응답 시간 초과: 서버 응답이 지연되고 있습니다.');
        } else {
          throw Exception('OCR 요청 실패: ${e.message}');
        }
      }
      rethrow;
    }
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
      print('[_onRegister] OCR 처리 시작');
      final ocrResult = await _sendOcrImage(_capturedImage!);
      
      if (!mounted) return;
      
             print('[_onRegister] OCR 처리 성공: $ocrResult');
       setState(() => _isLoading = false);
       
       // OCR 결과 검증
       if (ocrResult.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('OCR에서 차량 정보를 추출하지 못했습니다. 다른 이미지를 시도해주세요.')),
         );
         return;
       }
       
       // OCR 결과 상세 로깅
       print('[_onRegister] 반환할 OCR 결과:');
       ocrResult.forEach((key, value) {
         print('  $key: $value');
       });
       
       Navigator.pop(context, ocrResult);
    } catch (e, stackTrace) {
      setState(() => _isLoading = false);
      print('[_onRegister] 오류 발생: $e');
      print('[_onRegister] 스택 트레이스: $stackTrace');
      
      String errorMessage = 'OCR 요청 실패';
      if (e.toString().contains('500')) {
        errorMessage = '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = '요청 시간이 초과되었습니다. 네트워크 연결을 확인해주세요.';
      } else if (e.toString().contains('network')) {
        errorMessage = '네트워크 연결을 확인해주세요.';
      } else {
        errorMessage = e.toString();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '다시 시도',
              onPressed: () => _onRegister(context),
            ),
          ),
        );
      }
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
            Container(
              width: double.infinity,
              height: 400,
              decoration: BoxDecoration(color: cameraBoxColor, borderRadius: BorderRadius.circular(12)),
              child: _capturedImage != null
                  ? AspectRatio( // ✅ AspectRatio 위젯으로 감싸기
                aspectRatio: _cameraController.value.aspectRatio, // ✅ 카메라의 실제 종횡비 사용
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(_capturedImage!.path), fit: BoxFit.cover),
                ),
              )
                  : _isCameraInitialized && _cameraController.value.isInitialized
                  ? AspectRatio(
                aspectRatio: _cameraController.value.aspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CameraPreview(_cameraController),
                ),
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
                        backgroundColor: const Color(0xFF50C878),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: _isTakingPicture
                          ? const CircularProgressIndicator(color: Colors.black)
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