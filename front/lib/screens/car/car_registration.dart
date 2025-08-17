import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:moring/providers/api_client.dart';
import 'package:moring/providers/car_provider.dart';
import 'package:moring/providers/current_car_provider.dart';
import 'package:moring/providers/user_provider.dart';
import 'package:moring/utils/base_scaffold.dart';
import 'package:moring/models/car.dart';

class CarRegistrationPage extends ConsumerStatefulWidget {
  const CarRegistrationPage({Key? key}) : super(key: key);

  @override
  ConsumerState<CarRegistrationPage> createState() => _CarRegistrationPageState();
}

class _CarRegistrationPageState extends ConsumerState<CarRegistrationPage> {
  final TextEditingController _vinController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _registerDateController = TextEditingController();

  @override
  void dispose() {
    _vinController.dispose();
    _nicknameController.dispose();
    _modelController.dispose();
    _registerDateController.dispose();
    super.dispose();
  }

  Future<void> _selectRegisterDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: const Color(0xFF50C878),
              onPrimary: Colors.white,
              surface: const Color(0xFF23262B),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF181A20),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _registerDateController.text =
        "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _registerCar({
    // required String memberUuid,
    required String vin,
    required String modelName,
    required String nickname,
    required String registeredAt,
  }) async {
    final dio = ref.read(authDioProvider);

    final response = await dio.post(
      '/api/v1/cars/',
      data: {
        'vin': vin,
        'modelName': modelName,
        'nickname': nickname,
        'registeredAt': registeredAt,
      },
    );

    if (response.statusCode != 200 || response.data['isSuccess'] != true) {
      throw Exception(response.data['message'] ?? '차량 등록 실패');
    }
  }

    void _showFaceLineMeasurementModal(BuildContext context) {
    // WidgetsBinding.instance.addPostFrameCallback을 사용하여 다음 프레임에서 모달 표시
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showModalBottomSheet(
        context: context,
        barrierColor: Colors.black.withOpacity(0.3),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) {
          return Stack(
            children: [
              // 1. 블러 처리 레이어
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(color: Colors.transparent),
              ),
              // 2. 모달 내용
              Align(
                alignment: Alignment.bottomCenter,
                                 child: Container(
                   height: 220,
                   margin: const EdgeInsets.all(16),
                   padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
                                       decoration: BoxDecoration(
                      color: const Color(0xFF23262B),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 24,
                          offset: Offset(0, -6),
                        ),
                      ],
                    ),
                   child: Column(
                     mainAxisSize: MainAxisSize.min,
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                                                                                               const Text(
                            '10분간 페이스라인 측정 예정입니다.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                       const SizedBox(height: 12),
                                                                                                                       const Text(
                             '얼굴을 가리지 말고 운전해 주십시오.',
                             style: TextStyle(
                               color: Colors.white,
                               fontSize: 14,
                             ),
                             textAlign: TextAlign.center,
                           ),
                       const SizedBox(height: 8),
                                                                                                                                               const Text(
                              '(해당 시간 동안 일부 기능이 제한될 수 있습니다.)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                       const SizedBox(height: 20),
                       SizedBox(
                         width: double.infinity,
                         height: 48,
                                                  child: ElevatedButton(
                           style: ElevatedButton.styleFrom(
                             backgroundColor: Colors.white.withOpacity(0.24),
                             foregroundColor: Colors.white,
                             shape: RoundedRectangleBorder(
                               borderRadius: BorderRadius.circular(10),
                             ),
                           ),
                           onPressed: () {
                             Navigator.pop(context); // 모달 닫기
                             Navigator.pushReplacementNamed(context, '/registration_complete');
                           },
                                                                                                              child: const Text(
                             '확인',
                             style: TextStyle(
                               fontSize: 16,
                               fontWeight: FontWeight.bold,
                               color: Colors.white,
                             ),
                           ),
                         ),
                       ),
                     ],
                   ),
                 ),
              ),
            ],
          );
        },
      );
    });
  }

  Future<void> _onRegister() async {
    final vin = _vinController.text.trim();
    final nickname = _nicknameController.text.trim();
    final model = _modelController.text.trim();
    final registerDate = _registerDateController.text.trim();

    if (vin.isEmpty || nickname.isEmpty || model.isEmpty || registerDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 항목을 입력해 주세요.')),
      );
      return;
    }

    try {
    //   final userInfo = ref.read(userInfoProvider).maybeWhen(
    //     data: (user) => user,
    //     orElse: () => null,
    //   );
    //   if (userInfo == null) throw Exception('사용자 정보 없음');

      await _registerCar(
        // memberUuid: userInfo.uuid,
        vin: vin,
        modelName: model,
        nickname: nickname,
        registeredAt: registerDate,
      );

      // 1. carListProvider를 먼저 새로고침합니다.
      await ref.refresh(carListProvider.future);

      // 2. 새로운 차량의 VIN을 StateProvider에 저장합니다.
      ref.read(currentVinProvider.notifier).state = vin;

      // 3. selectedCarIndexProvider를 새로 등록된 차량의 인덱스로 설정합니다.
      final cars = ref.read(carListProvider).maybeWhen(
        data: (list) => list,
        orElse: () => <Car>[],
      );

      final newCarIndex = cars.indexWhere((car) => car.vin == vin);
      if (newCarIndex != -1) {
        ref.read(selectedCarIndexProvider.notifier).state = newCarIndex;
      }

             // 4. Provider 동기화가 완료될 때까지 잠시 대기
       await Future.delayed(const Duration(milliseconds: 100));

               // 차량 등록 완료 후 페이스라인 측정 안내 모달 표시
        _showFaceLineMeasurementModal(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('등록 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryBlue = const Color(0xFF2196F3);
    final darkField = const Color(0xFF23262B);

    return BaseScaffold(
      title: '차량 등록',
      withBottomNav: false,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 30, 15, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _vinController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: darkField,
                  labelText: '차대번호',
                  labelStyle: const TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nicknameController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: darkField,
                  labelText: '애칭',
                  labelStyle: const TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                ),
              ),
              const SizedBox(height: 16),
              // TextField(
              //   controller: _modelController,
              //   style: const TextStyle(color: Colors.white, fontSize: 16),
              //   decoration: InputDecoration(
              //     filled: true,
              //     fillColor: darkField,
              //     hintText: '모델명',
              //     hintStyle: const TextStyle(color: Colors.white38),
              //     border: OutlineInputBorder(
              //       borderRadius: BorderRadius.circular(8),
              //       borderSide: BorderSide.none,
              //     ),
              //     contentPadding:
              //     const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
              //   ),
              // ),
              TextFormField(
                controller: _modelController,
                readOnly: true, // 직접 입력 안 하고 선택만 가능
                onTap: () async {
                  final selected = await showMenu<String>(
                    context: context,
                    position: const RelativeRect.fromLTRB(100, 300, 100, 100),
                    items: [
                      const PopupMenuItem<String>(value: 'XM3', child: Text('XM3')),
                      const PopupMenuItem<String>(value: '그랜저', child: Text('그랜저')),
                      const PopupMenuItem<String>(value: '모닝', child: Text('모닝')),
                      const PopupMenuItem<String>(value: '스포티지', child: Text('스포티지')),
                      const PopupMenuItem<String>(value: '아반떼', child: Text('아반떼')),
                      const PopupMenuItem<String>(value: '코나', child: Text('코나')),
                      const PopupMenuItem<String>(value: '투싼', child: Text('투싼')),
                    ],
                  );
                  if (selected != null) {
                    setState(() {
                      _modelController.text = selected;
                    });
                  }
                },
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: darkField,
                  labelText: '모델명',
                  labelStyle: const TextStyle(color: Colors.white38),
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                  suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                ),
              ),

              const SizedBox(height: 16),
              TextField(
                controller: _registerDateController,
                readOnly: true,
                onTap: _selectRegisterDate,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: darkField,
                  labelText: '등록일',
                  labelStyle: const TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                  suffixIcon:
                  const Icon(Icons.calendar_today, color: Colors.white54),
                ),
              ),
              const SizedBox(height: 26),
              ElevatedButton(
                onPressed: _onRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF50C878),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  '등록하기',
                  style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.white10)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child:
                    Text('or', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ),
                  Expanded(child: Divider(color: Colors.white10)),
                ],
              ),
              const SizedBox(height: 14),
                             SizedBox(
                 height: 46,
                 child: OutlinedButton(
                   style: OutlinedButton.styleFrom(
                     foregroundColor: Colors.white,
                     side: const BorderSide(color: Colors.white38, width: 1.2),
                     shape: RoundedRectangleBorder(
                       borderRadius: BorderRadius.circular(10),
                     ),
                   ),
                   onPressed: () async {
                     final result = await Navigator.pushNamed(context, '/car_ocr');

                     // OCR 결과 디버깅
                     print('[OCR 결과] 받은 데이터: $result');
                     print('[OCR 결과] 데이터 타입: ${result.runtimeType}');

                     // result는 OCR 페이지에서 pop할 때 전달한 데이터(Map 등)임
                     if (result != null && result is Map<String, dynamic>) {
                       print('[OCR 결과] VIN: ${result['vin']}');
                       print('[OCR 결과] Model: ${result['modelName']}');
                       print('[OCR 결과] Date: ${result['registeredAt']}');
                       
                       // 다양한 필드명 시도
                       final vin = result['vin'] ?? result['VIN'] ?? result['vehicleNumber'] ?? '';
                       final model = result['modelName'] ?? result['model'] ?? result['vehicleModel'] ?? '';
                       String date = result['registeredAt'] ?? result['registrationDate'] ?? result['date'] ?? '';
                       
                       // 날짜 형식 변환 (YYYY.MM.DD -> YYYY-MM-DD)
                       if (date.isNotEmpty && date.contains('.')) {
                         date = date.replaceAll('.', '-');
                       }
                       
                       print('[OCR 결과] 파싱된 VIN: $vin');
                       print('[OCR 결과] 파싱된 Model: $model');
                       print('[OCR 결과] 파싱된 Date: $date');
                       
                       setState(() {
                         _vinController.text = vin;
                         _modelController.text = model;
                         _registerDateController.text = date;
                       });
                       
                       // 성공 메시지 표시
                       if (vin.isNotEmpty || model.isNotEmpty) {
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(
                             content: Text('OCR 결과가 입력창에 적용되었습니다.'),
                             duration: Duration(seconds: 2),
                           ),
                         );
                       } else {
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(
                             content: Text('OCR에서 차량 정보를 추출하지 못했습니다.'),
                             duration: Duration(seconds: 3),
                           ),
                         );
                       }
                     } else {
                       print('[OCR 결과] 결과가 null이거나 Map이 아님: $result');
                     }
                   },
                   child: const Text(
                     '차량 등록증 스캔',
                     style: TextStyle(fontSize: 16),
                   ),
                 ),
               ),
            ],
          ),
        ),
      ),
    );
  }
}
