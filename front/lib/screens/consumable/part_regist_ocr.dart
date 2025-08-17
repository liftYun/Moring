import 'dart:io';
import 'package:path/path.dart' as p; // path 패키지에 접두사 'p' 추가
import 'package:mime/mime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moring/utils/custom_app_bar.dart';
import 'package:moring/providers/api_client.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:moring/screens/consumable/part_change.dart';
import 'package:permission_handler/permission_handler.dart';

List<CameraDescription>? cameras;

class PartOcrRegistrationPage extends ConsumerStatefulWidget {
  // VIN 값을 전달받도록 수정
  final String vin;
  const PartOcrRegistrationPage({Key? key, required this.vin}) : super(key: key);

  @override
  ConsumerState<PartOcrRegistrationPage> createState() => _PartOcrRegistrationPageState();
}

class _PartOcrRegistrationPageState extends ConsumerState<PartOcrRegistrationPage> {
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

  Future<bool> _requestPermission(Permission permission) async {
    print('[_requestPermission] 권한 요청 시작: $permission');
    
    try {
      // 먼저 현재 권한 상태 확인
      final status = await permission.status;
      print('[_requestPermission] 현재 권한 상태: $status');
      
      if (status.isGranted) {
        print('[_requestPermission] 권한이 이미 허용됨');
        return true;
      }
      
      // 권한이 거부된 경우 바로 시스템 권한 요청
      if (status.isDenied) {
        print('[_requestPermission] 시스템 권한 요청 다이얼로그 표시');
        final result = await permission.request();
        print('[_requestPermission] 권한 요청 결과: $result');
        return result.isGranted;
      }
      
      // 권한이 영구적으로 거부된 경우 커스텀 메시지 표시
      if (status.isPermanentlyDenied) {
        print('[_requestPermission] 영구 거부 상태 - 커스텀 다이얼로그 표시');
        
        if (!mounted) return false;
        
        String permissionMessage = '';
        if (permission == Permission.camera) {
          permissionMessage = '카메라 권한이 필요합니다.\n소모품 교체 이력을 촬영하기 위해 카메라 접근을 허용해주세요.';
        } else if (permission == Permission.photos || permission == Permission.storage || permission == Permission.mediaLibrary) {
          permissionMessage = '갤러리 접근 권한이 필요합니다.\n소모품 교체 이력 사진을 선택하기 위해 갤러리 접근을 허용해주세요.';
        }
        
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF232326),
              title: const Text(
                '권한 필요',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: Text(
                permissionMessage,
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    '확인',
                    style: TextStyle(color: Color(0xFF50C878)),
                  ),
                ),
              ],
            );
          },
        );
        return false;
      }
      
      print('[_requestPermission] 알 수 없는 권한 상태: $status');
      return false;
    } catch (e) {
      print('[_requestPermission] 권한 요청 중 오류 발생: $e');
      return false;
    }
  }

  Future<void> _takePicture() async {
    print('[_takePicture] 함수 호출됨');
    
    // 권한 요청
    final hasPermission = await _requestPermission(Permission.camera);
    print('[_takePicture] 권한 상태: $hasPermission');
    
    if (!hasPermission) {
      print('[_takePicture] 권한이 거부됨');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카메라 권한이 필요합니다.')),
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
      print('[_takePicture] 오류 발생: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사진 촬영 실패: $e')),
      );
    } finally {
      setState(() => _isTakingPicture = false);
    }
  }

  Future<void> _pickImageFromGallery() async {
    print('[_pickImageFromGallery] 함수 호출됨');
    
    // 여러 권한을 순차적으로 시도
    List<Permission> permissionsToTry = [
      Permission.photos,
      Permission.storage,
      Permission.mediaLibrary,
    ];
    
    bool hasPermission = false;
    
    for (Permission permission in permissionsToTry) {
      print('[_pickImageFromGallery] 권한 시도: $permission');
      
      hasPermission = await _requestPermission(permission);
      print('[_pickImageFromGallery] 권한 상태: $hasPermission');
      
      if (hasPermission) {
        print('[_pickImageFromGallery] 권한 획득 성공: $permission');
        break;
      }
    }
    
    if (!hasPermission) {
      print('[_pickImageFromGallery] 모든 권한이 거부됨');
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

    final mimeType = lookupMimeType(imageFile.path) ?? 'application/octet-stream';
    final mimeParts = mimeType.split('/');

    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: 'ocr_image${p.extension(imageFile.path)}',
        contentType: MediaType(mimeParts[0], mimeParts[1]),
      ),
    });

    final response = await dio.post(
      '/api/v1/AI/part-repair-estimate-ocr',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    if (response.statusCode != 200 || response.data == null) {
      throw Exception(response.data['message'] ?? 'OCR 처리 실패');
    }

    print('[_sendOcrImage] API 응답 데이터: ${response.data}');
    print('[_sendOcrImage] 추출된 result 값: ${response.data}');
    return Map<String, dynamic>.from(response.data);
  }

  Future<void> _onRegister(BuildContext context) async {
    debugPrint("[_onRegister] 호출됨");
    if (_isLoading) return;
    if (_capturedImage == null) {
      debugPrint("[_onRegister] _capturedImage = null");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지를 먼저 촬영 또는 선택하세요.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final ocrResult = await _sendOcrImage(_capturedImage!);
      debugPrint("[_onRegister] OCR 결과: $ocrResult");
      if (!mounted) return;
      setState(() => _isLoading = false);

      // OCR 결과에서 부품 IDs 추출 (parts 또는 partIdList 필드 확인)
      final List<int>? updatedPartIds = ocrResult['parts']?.cast<int>() ?? ocrResult['partIdList']?.cast<int>();
      debugPrint("[_onRegister] OCR 결과 전체: $ocrResult");
      debugPrint("[_onRegister] parts 필드: ${ocrResult['parts']}");
      debugPrint("[_onRegister] partIdList 필드: ${ocrResult['partIdList']}");
      debugPrint("[_onRegister] 추출된 부품 IDs: $updatedPartIds");

      if (updatedPartIds != null && updatedPartIds.isNotEmpty) {
        // OCR 결과를 상위로 전달 (BulkPartRegistrationPage에서 처리)
        debugPrint("[_onRegister] OCR 결과를 상위로 전달: $ocrResult");
        if (!mounted) return;
        Navigator.pop(context, ocrResult);
      } else {
        debugPrint("[_onRegister] OCR 결과에서 부품 IDs를 찾을 수 없음");
        if (!mounted) return;
        Navigator.pop(context, null);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("[_onRegister] 오류 발생: $e");

      if (!mounted) return;
      Navigator.pop(context, null); // 오류 발생 시 null 반환

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR 요청 실패: $e')),
      );
    }
  }

  Future<void> _postBatchChangeLogs(String changedAt, List<int> partIdList) async {
    final dio = ref.read(authDioProvider);
    try {
        final data = {
          'vin': widget.vin,
          'partIdList': partIdList,
          'changedAt': changedAt + 'T00:00:00.000Z',
        };
        await dio.post('/api/v1/parts/change-log', data: data);


      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('교체 이력이 성공적으로 등록되었습니다!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이력 등록 실패: $e')),
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
                      onPressed: _isTakingPicture ? null : () => _takePicture(),
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
                      onPressed: () => _pickImageFromGallery(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white38),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '갤러리에서 선택하기',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
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
                        : const Icon(Icons.check_circle, size: 48, color: Colors.greenAccent),
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