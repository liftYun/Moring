import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/models/user_info.dart';
import 'package:moring/providers/user_provider.dart';

class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userInfoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Page')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('에러: $err')),
        data: (user) => _buildContent(context, user),
      ),
    );
  }

  Widget _buildContent(BuildContext context, UserInfo user) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 프로필 사진
          CircleAvatar(
            radius: 40,
            // backgroundImage:
            // user.profileUrl.isNotEmpty ? NetworkImage(user.profileUrl) : null,
            // child: user.profileUrl.isEmpty ? const Icon(Icons.person, size: 40) : null,
          ),
          const SizedBox(height: 16),

          // 닉네임
          Text(
            user.nickname,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),

          // 이메일
          Text(
            user.email,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),

          const SizedBox(height: 24),
          // 추가 정보(예: 차량, 소모품 등) 버튼 등
          ElevatedButton.icon(
            onPressed: () {
              // 예: 프로필 편집 페이지로 이동
            },
            icon: const Icon(Icons.edit),
            label: const Text('프로필 편집'),
          ),
        ],
      ),
    );
  }
}
