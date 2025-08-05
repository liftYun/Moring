import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/services/social_auth_service.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _loading = false;

  Future<void> _kakaoLogin() async {
    setState(() => _loading = true);
    try {
      await ref.read(socialAuthServiceProvider).loginWithKakao();
      if (mounted) Navigator.pushReplacementNamed(context, '/carselection');
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('로그인에 실패했습니다.')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _testLogin() async {
    setState(() => _loading = true);
    try {
      await ref.read(socialAuthServiceProvider).loginWithTest();
      if (mounted) Navigator.pushReplacementNamed(context, '/carselection');
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('로그인에 실패했습니다.')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _SocialLoginButton({
    required String label,
    required String iconPath,
    required Color backgroundColor,
    Color? foregroundColor,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor ?? Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 로딩 상태에 따라 아이콘과 로딩 위젯 전환
            _loading
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.black,
              ),
            )
                : Image.asset(
              iconPath,
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 8),
            // 로딩 상태에 따라 텍스트 변경
            _loading
                ? const Text('') // 로딩 중일 때는 빈 텍스트
                : Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF18181C),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                const Text(
                  '환영합니다!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  '계정에 로그인 해주세요.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFFCBCBCB),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 120),

                // 카카오 로그인 버튼
                _SocialLoginButton(
                  label: '카카오로 로그인하기',
                  iconPath: 'assets/kakao_logo.jpg',
                  backgroundColor: const Color(0xFFFFE812),
                  foregroundColor: Colors.black,
                  onPressed: _loading ? null : _kakaoLogin,
                ),

                const SizedBox(height: 14),

                // 구글 로그인 버튼
                // 구글 버튼 스타일은 별도로 수정이 필요합니다.
                // OutlinedButton 스타일은 이 위젯에서 직접 구현하거나,
                // SocialLoginButton 위젯에 isOutlined 등의 파라미터를 추가하여 구현할 수 있습니다.
                _SocialLoginButton(
                  label: '구글로 로그인하기',
                  iconPath: 'assets/google_logo.png',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  onPressed: _loading ? null : _testLogin,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}