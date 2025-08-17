import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/models/user_info.dart';
import 'package:moring/providers/user_provider.dart';

import 'package:moring/utils/base_scaffold.dart';
import 'package:moring/utils/policy_content.dart';

class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userInfoProvider);

    return BaseScaffold(
      title: 'My Page',
      onBackButtonPressed: () => Navigator.pop(context),
      showBack: true,
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('에러: $err')),
        data: (user) => _buildContent(context, user),
      ),
    );
  }

  Widget _buildContent(BuildContext context, UserInfo user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 프로필 섹션
          _buildProfileSection(context, user),
          const SizedBox(height: 24),
          
          // 계정 관리 섹션
          _buildAccountSection(context),
          const SizedBox(height: 24),
          
          // 정책 섹션
          _buildPolicySection(context),
          const SizedBox(height: 24),
          
          // 앱 정보 섹션
          _buildAppInfoSection(context),
        ],
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context, UserInfo user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person, size: 40, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(
              user.nickname,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              user.email,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/user-info-edit');
              },
              icon: const Icon(Icons.edit),
              label: const Text('프로필 편집'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF50C878),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _buildListTile(
            context,
            icon: Icons.notifications,
            title: '알림 설정',
            subtitle: '알림 권한 및 설정 관리',
            onTap: () {
              // 알림 설정 페이지로 이동
            },
          ),
          _buildListTile(
            context,
            icon: Icons.security,
            title: '보안 설정',
            subtitle: '비밀번호 변경 및 보안 관리',
            onTap: () {
              // 보안 설정 페이지로 이동
            },
          ),
          _buildListTile(
            context,
            icon: Icons.logout,
            title: '로그아웃',
            subtitle: '계정에서 로그아웃',
            onTap: () {
              _showLogoutDialog(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPolicySection(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '정책 및 약관',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildListTile(
            context,
            icon: Icons.privacy_tip,
            title: '개인정보처리방침',
            subtitle: '개인정보 수집 및 이용에 관한 안내',
            onTap: () => _showPolicyDialog(context, '개인정보처리방침', PolicyContent.getPrivacyPolicy()),
          ),
          _buildListTile(
            context,
            icon: Icons.description,
            title: '이용약관',
            subtitle: '서비스 이용에 관한 약관',
            onTap: () => _showPolicyDialog(context, '이용약관', PolicyContent.getTermsOfService()),
          ),
          _buildListTile(
            context,
            icon: Icons.safety_check,
            title: '운전자 안전 정책',
            subtitle: '안전 운전을 위한 가이드라인',
            onTap: () => _showPolicyDialog(context, '운전자 안전 정책', PolicyContent.getSafetyPolicy()),
          ),
          _buildListTile(
            context,
            icon: Icons.data_usage,
            title: '데이터 수집 및 사용 정책',
            subtitle: '운전 데이터 수집 및 활용에 관한 안내',
            onTap: () => _showPolicyDialog(context, '데이터 수집 및 사용 정책', PolicyContent.getDataPolicy()),
          ),
          _buildListTile(
            context,
            icon: Icons.notifications_active,
            title: '알림 설정 정책',
            subtitle: '알림 서비스 이용에 관한 안내',
            onTap: () => _showPolicyDialog(context, '알림 설정 정책', PolicyContent.getNotificationPolicy()),
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfoSection(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _buildListTile(
            context,
            icon: Icons.info,
            title: '앱 정보',
            subtitle: '버전 1.0.0',
            onTap: () {
              // 앱 정보 페이지로 이동
            },
          ),
          _buildListTile(
            context,
            icon: Icons.help,
            title: '도움말',
            subtitle: '자주 묻는 질문 및 사용법',
            onTap: () {
              // 도움말 페이지로 이동
            },
          ),
          _buildListTile(
            context,
            icon: Icons.contact_support,
            title: '고객지원',
            subtitle: '문의사항 및 피드백',
            onTap: () {
              // 고객지원 페이지로 이동
            },
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF50C878)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              // 로그아웃 로직 구현
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF50C878),
              foregroundColor: Colors.white,
            ),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }

  void _showPolicyDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(content),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF50C878),
              foregroundColor: Colors.white,
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }


}
