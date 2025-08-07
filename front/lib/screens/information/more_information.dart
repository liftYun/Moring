// lib/screens/information/more_information.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/providers/user_provider.dart'; // userInfoProvider
import 'package:moring/models/user_info.dart';

import 'package:moring/screens//member/user_info_edit.dart';
import 'package:moring/screens/information/notification_panel.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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

    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            // --- Profile 섹션 ---
            _buildSectionHeader(context, '프로필'),
            // 실제 유저 정보를 불러와서 렌더링
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
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

            // --- App Settings 섹션 ---
            _buildSectionHeader(context, ''),
            _buildTile(
              icon: Icons.event_note,
              title: '점검 로그',
              subtitle: '점검일을 확인하세요',
              onTap: () {
                // App Preferences 페이지
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
              },
            ),

            // --- Support 섹션 ---
            _buildSectionHeader(context, 'Support'),
            _buildTile(
              icon: Icons.help_outline,
              title: 'Help Center',
              subtitle: 'Get help with the app',
              onTap: () {
                // Help Center 페이지
              },
            ),
            _buildTile(
              icon: Icons.mail_outline,
              title: 'Contact Us',
              subtitle: 'Contact us for support',
              onTap: () {
                // Contact Us 페이지
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
