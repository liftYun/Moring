import 'package:flutter/material.dart';

class MorePage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            // --- AppBar 영역만 빌드 위젯 쪽에서 컨트롤하므로 생략 ---
            // 섹션: Profile
            _buildSectionHeader(context, 'Profile'),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                radius: 28,
                backgroundImage: NetworkImage('https://placehold.co/56x56'),
              ),
              title: const Text(
                'Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: const Text(
                'Edit your profile',
                style: TextStyle(
                  color: Color(0xFF9BAABA),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              onTap: () {
                // 프로필 편집 페이지로 이동
              },
            ),

            // 섹션: App Settings
            _buildSectionHeader(context, 'App Settings'),
            _buildTile(
              icon: Icons.settings_outlined,
              title: 'App Preferences',
              subtitle: 'Manage your app preferences',
              onTap: () {
                // App Preferences 페이지
              },
            ),
            _buildTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Manage your notifications',
              onTap: () {
                // Notifications 페이지
              },
            ),
            _buildTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy',
              subtitle: 'Manage your privacy settings',
              onTap: () {
                // Privacy 페이지
              },
            ),

            // 섹션: Support
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
