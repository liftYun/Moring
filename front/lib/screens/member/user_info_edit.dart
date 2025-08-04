// lib/screens/information/profile_edit_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/models/user_info.dart';
import 'package:moring/models/car.dart';
import 'package:moring/providers/user_provider.dart';
import 'package:moring/providers/car_provider.dart';

import '../../services/user_service.dart';

class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nicknameController;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    final user = ref.read(userInfoProvider).maybeWhen(
      data: (u) => u,
      orElse: () => null,
    );
    _nicknameController = TextEditingController(text: user?.nickname ?? '');
    _emailController    = TextEditingController(text: user?.email    ?? '');
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    final newNick = _nicknameController.text.trim();

    try {
      // 1) 서버에 PATCH 요청
      await ref.read(userServiceProvider).updateNickName(newNick);

      // 2) userInfoProvider를 즉시 리프레시
      final updatedUser = await ref.refresh(userInfoProvider.future);

      // 3) 컨트롤러에도 새 값 반영
      _nicknameController.text = updatedUser.nickname;
      _emailController.text    = updatedUser.email;

      // 4) 스낵바 알림 (화면은 그대로)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임이 정상적으로 변경되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('변경에 실패했습니다: $e')),
      );
    }
  }



  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userInfoProvider);
    final carsAsync = ref.watch(carListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF111416),
      appBar: AppBar(
        title: const Text('Edit Information'),
        backgroundColor: const Color(0xFF111416),
        elevation: 0,
      ),
      body: SafeArea(
        child: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('유저 로드 에러: $e')),
          data: (user) => carsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('차량 로드 에러: $e')),
            data: (cars) => Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // --- Nickname ---
                  _buildSectionHeader('Nickname'),
                  TextFormField(
                    controller: _nicknameController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF283038),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    style: const TextStyle(color: Colors.white),
                    validator: (v) =>
                    (v == null || v.isEmpty) ? '닉네임을 입력해주세요' : null,
                  ),

                  // --- Email (읽기 전용) ---
                  _buildSectionHeader('Email'),
                  TextFormField(
                    controller: _emailController,
                    readOnly: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF283038),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    style: const TextStyle(color: Colors.white70),
                  ),

                  // --- 등록된 차량 (수정 불가) ---
                  _buildSectionHeader('등록된 차량'),
                  ...cars.map((c) => Card(
                    color: const Color(0xFF283038),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: Icon(Icons.directions_car, color: Colors.white),
                      title: Text(
                        c.nickname.isNotEmpty ? c.nickname : c.modelName,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        c.modelName,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  )),

                  const SizedBox(height: 32),

                  // --- Save Button ---
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A7FED),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: _saveChanges,
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
