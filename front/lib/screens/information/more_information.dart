import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/providers/user_provider.dart'; // userInfoProvider
import 'package:moring/providers/notification_api_provider.dart';
import 'package:moring/models/user_info.dart';

import 'package:moring/screens/member/user_info_edit.dart';
import 'package:moring/screens/information/notification_panel.dart';
import 'package:moring/screens/car/car_registration.dart';
import 'package:moring/screens/information/inspection_detail_page.dart';

// 푸시 알림 허용 여부 상태 프로바이더 정의
final pushNotificationAllowedProvider = StateProvider<bool>((ref) {
  // 초기값 true로 설정, 기기 권한 등 상태와 동기화 하는 로직 필요하면 여기에 구현
  return true;
});

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

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
                onTap: () {
                  // 프로필 편집 페이지로 이동
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileEditPage()),
                  );
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
                    activeTrackColor: Colors.blue,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFF23262B),
                  ),
                ],
              ),
            ),

            // --- 기타 설정 섹션 ---
            _buildSectionHeader(context, ref, ''),
            _buildTile(
              icon: Icons.directions_car_outlined,
              title: '차량 등록',
              subtitle: '새로운 차량을 등록하세요',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CarRegistrationPage()),
                );
              },
            ),

            _buildTile(
              icon: Icons.event_note,
              title: '점검 로그',
              subtitle: '점검일을 확인하세요',
              onTap: () {

              },
            ),
            _buildTile(
              icon: Icons.notifications_outlined,
              title: '알림',
              subtitle: '알림을 관리하세요',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationPanel()),
                );
              },
            ),
            _buildTile(
              icon: Icons.privacy_tip_outlined,
              title: '정책',
              subtitle: '사용 정책을 확인하세요',
              onTap: () {
                // TODO: 정책 페이지 이동 구현
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
