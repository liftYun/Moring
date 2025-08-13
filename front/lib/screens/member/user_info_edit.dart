import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/providers/user_provider.dart';
import 'package:moring/providers/car_provider.dart';
import 'package:moring/utils/base_scaffold.dart';
import 'package:moring/providers/api_client.dart';
import 'package:moring/services/user_service.dart';
import 'package:moring/screens/information/more_information.dart';

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
    _emailController = TextEditingController(text: user?.email ?? '');
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
      // 닉네임 변경
      await ref.read(userServiceProvider).updateNickName(newNick);

      // 즉시 사용자 정보 리프레시
      final updatedUser = await ref.refresh(userInfoProvider.future);

      // 컨트롤러 값 업데이트
      _nicknameController.text = updatedUser.nickname;
      _emailController.text = updatedUser.email;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임이 정상적으로 변경되었습니다.')),
      );

      if (context.mounted) {
        Navigator.pop(context, true);
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('변경에 실패했습니다: $e')),
      );
    }
  }

  Future<bool> _deleteCarByVin(String vin) async {
    final dio = ref.read(authDioProvider);
    try {
      final response = await dio.delete('/api/v1/cars/$vin');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Delete failed: $e');
      return false;
    }
  }

  /// CarInfoPage 스타일 삭제 확인 바텀시트
  void _showDeleteBottomSheet(BuildContext context, String vin, String carName) {
    showModalBottomSheet(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Stack(
            children: [
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(
                  color: Colors.transparent,
                  height: 220,
                ),
              ),
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF23262B),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '차량을 삭제하시겠습니까?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '삭제 시 입력된 모든 정보가 완전히 삭제됩니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('취소'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              Navigator.pop(context); // 모달 닫기
                              final success = await _deleteCarByVin(vin);
                              if (success) {
                                ref.refresh(carListProvider);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('차량이 삭제되었습니다.')),
                                );
                              } else {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('삭제에 실패했습니다. 관리자에게 문의하세요.'),
                                  ),
                                );
                              }
                            },
                            child: const Text('삭제'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
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

    return BaseScaffold(
      title: '회원 정보 수정',
      withBottomNav: false,
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
                  // 닉네임
                  _buildSectionHeader('닉네임'),
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

                  // 이메일
                  _buildSectionHeader('이메일'),
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

                  // 등록된 차량 리스트 + 삭제 버튼
                  _buildSectionHeader('등록된 차량'),
                  ...cars.map((c) => Card(
                    color: const Color(0xFF283038),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: const Icon(Icons.directions_car, color: Colors.white),
                      title: Text(
                        c.nickname.isNotEmpty ? c.nickname : c.modelName,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        c.modelName,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                        tooltip: '삭제',
                        onPressed: () {
                          _showDeleteBottomSheet(
                            context,
                            c.vin,
                            c.nickname.isNotEmpty ? c.nickname : c.modelName,
                          );
                        },
                      ),
                    ),
                  )),

                  const SizedBox(height: 32),

                  // 저장 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF50C878), // ✅ 색상 변경
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10), // ✅ 각진 네모로 변경 (반경 10)
                        ),
                      ),
                      onPressed: _saveChanges,
                      child: const Text(
                        '저장',
                        style: TextStyle(
                          color: Colors.black, // ✅ 글씨 색상 검정색으로 변경
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
