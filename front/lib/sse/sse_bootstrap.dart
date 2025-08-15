// lib/sse/sse_bootstrap.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:moring/providers/car_provider.dart'; // currentVinProvider, currentCarNicknameProvider 등
import 'package:moring/sse/sse_hub.dart';

/// 전역에서 현재 VIN 변화를 감지해 SSEHub에 전달하는 아주 얇은 위젯.
/// UI는 없고, 소켓만 관리합니다.
class SseBootstrap extends ConsumerWidget {
  const SseBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1) VIN 변화를 구독(변할 때마다 호출됨)
    ref.listen<String?>(currentVinProvider, (prev, next) {
      ref.read(sseHubProvider).switchVin(next);
    });

    // 2) 최초 1회 연결 보장: 현재 VIN으로 switchVin 호출
    final vin = ref.watch(currentVinProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 같은 값이면 내부에서 무시됨
      ref.read(sseHubProvider).switchVin(vin);
    });

    return const SizedBox.shrink();
  }
}
