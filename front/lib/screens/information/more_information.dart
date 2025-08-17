import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import 'package:moring/models/user_info.dart';
import 'package:moring/providers/user_provider.dart'; // userInfoProvider
import 'package:moring/providers/notification_api_provider.dart';

import 'package:moring/screens/member/user_info_edit.dart';
import 'package:moring/screens/car/car_registration.dart';
import 'package:moring/screens/information/inspection_detail_container.dart';
import 'package:moring/screens/information/notification_log.dart';
import 'package:moring/screens/navigation/information/backup_settings.dart';

// 로그아웃 관련 import (추가)
import 'package:moring/providers/auth_provider.dart';
import 'package:moring/providers/token_repository.dart';
import 'package:moring/providers/car_provider.dart';
import 'package:moring/providers/api_client.dart';

final pushNotificationAllowedProvider = StateProvider<bool>((ref) {
  return true;
});

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  /// 로그아웃 처리
  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(tokenRepositoryProvider);
      final refreshToken = await repo.getRefreshToken();
      final dio = ref.read(noAuthDioProvider);
      final resp = await dio.post(
        '/api/v1/auth/logout/rToken',
        options: Options(
          headers: {'Cookie': 'refreshToken=$refreshToken'},
          validateStatus: (s) => s != null && s < 400,
        ),
      );
      if (resp.statusCode == 200 || resp.statusCode == 302) {
        await repo.deleteAllTokens();
        ref.read(selectedCarIndexProvider.notifier).state = 0;
        ref.refresh(userInfoProvider);
        ref.refresh(carListProvider);
        ref.refresh(currentVinProvider);
        ref.invalidate(authDioProvider);
        ref.invalidate(noAuthDioProvider);

        // 로그인 화면으로 이동 (라우트 이름 수정 필요시 '/login' 확인)
        // if (context.mounted) {
        //   Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        // }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그아웃에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('에러 발생: $e')),
      );
    }
  }

  Widget _buildSectionHeader(BuildContext context, WidgetRef ref, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF283038),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: Color(0xFF9BAABA),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<UserInfo> userAsync = ref.watch(userInfoProvider);
    final isNotiAllowed = ref.watch(pushNotificationAllowedProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // --- Profile 섹션 ---
            _buildSectionHeader(context, ref, '프로필'),
            userAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    '프로필 로드 실패: $err',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
              data: (user) => ListTile(
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundImage: user.profileUrl.isNotEmpty
                      ? NetworkImage(user.profileUrl)
                      : null,
                  child: user.profileUrl.isEmpty
                      ? const Icon(Icons.person, size: 28)
                      : null,
                ),
                title: Text(
                  user.nickname,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  user.email,
                  style: const TextStyle(
                      color: Color(0xFF9BAABA),
                      fontSize: 14,
                      fontWeight: FontWeight.w400),
                ),
                onTap: () async {
                  // 프로필 편집 페이지로 이동, 수정 완료 후 돌아오면 상태 새로고침
                  final updated = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileEditPage()),
                  );
                  if (updated == true) {
                    ref.refresh(userInfoProvider);
                  }
                },
              ),
            ),

            // --- 푸시알림 허용 토글 섹션 ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '알림 허용',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Switch(
                    value: isNotiAllowed,
                    onChanged: (value) {
                      ref.read(pushNotificationAllowedProvider.notifier).state = value;
                      // TODO: 실제 푸시 권한 허용/차단 로직 호출
                    },
                    activeColor: Colors.white,
                    activeTrackColor: const Color(0xFF50C878),
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFF23262B),
                  ),
                ],
              ),
            ),

            // --- 기타 설정 섹션 ---
            _buildSectionHeader(context, ref, ''),
            // _buildTile(
            //   icon: Icons.backup,
            //   title: '백업 설정',
            //   subtitle: '주행 로그 백업을 관리하세요.',
            //   onTap: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(builder: (context) => const BackupSettingsPage()),
            //     );
            //   },
            // ),
            _buildTile(
              icon: Icons.event_note,
              title: '점검 로그',
              subtitle: '점검일을 확인하세요.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const InspectionDetailContainerPage()),
                );
              },
            ),
            _buildTile(
              icon: Icons.notifications_outlined,
              title: '알림',
              subtitle: '알림을 관리하세요.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationLogPage()),
                );
              },
            ),
            _buildTile(
              icon: Icons.privacy_tip_outlined,
              title: '정책',
              subtitle: '사용 정책을 확인하세요.',
              onTap: () {
                // TODO: 정책 페이지 이동 구현
              },
            ),

            const Divider(color: Colors.white24, height: 32),

            // --- 로그아웃 버튼 추가 ---
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF283038),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.logout, color: Colors.white),
              ),
              title: const Text(
                '로그아웃',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              onTap: () async {
                // 확인 다이얼로그 후 진행
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: Colors.grey[900],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('로그아웃', style: TextStyle(color: Colors.white)),
                    content: const Text('정말 로그아웃 하시겠습니까?', style: TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.white70),
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('로그아웃'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await _logout(context, ref);
                }
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
