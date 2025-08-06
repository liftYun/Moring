import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:moring/providers/api_client.dart';
import 'package:moring/utils/base_scaffold.dart';

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
              primary: const Color(0xFF2196F3),
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

  void _onRegister() async {
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
      // final userInfo = ref.read(userInfoProvider).maybeWhen(
      //   data: (user) => user,
      //   orElse: () => null,
      // );
      // if (userInfo == null) throw Exception('사용자 정보 없음');

      await _registerCar(
        // memberUuid: userInfo.uuid,
        vin: vin,
        modelName: model,
        nickname: nickname,
        registeredAt: registerDate,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('차량이 등록되었습니다!')),
      );

      Navigator.pushReplacementNamed(
          context,
          '/registration_complete',
          arguments: {'modelName': model},
      );
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
                  hintText: '차대번호',
                  hintStyle: const TextStyle(color: Colors.white38),
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
                  hintText: '애칭',
                  hintStyle: const TextStyle(color: Colors.white38),
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
                controller: _modelController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: darkField,
                  hintText: '모델명',
                  hintStyle: const TextStyle(color: Colors.white38),
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
                controller: _registerDateController,
                readOnly: true,
                onTap: _selectRegisterDate,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: darkField,
                  hintText: '등록일',
                  hintStyle: const TextStyle(color: Colors.white38),
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
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _onRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '등록하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
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
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/ocr');
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
