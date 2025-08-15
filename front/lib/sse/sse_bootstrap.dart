// lib/sse/sse_bootstrap.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:moring/providers/car_provider.dart'; // currentVinProvider
import 'package:moring/sse/sse_hub.dart';

/// 전역에서 현재 VIN 변화를 감지해 SSEHub에 전달.
/// UI는 없고 소켓만 관리.
class SseBootstrap extends ConsumerWidget {
  const SseBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // VIN이 바뀔 때마다 허브에 반영
    ref.listen<String?>(currentVinProvider, (prev, next) {
      ref.read(sseHubProvider).switchVin(next);
    });

    // 첫 빌드 시 현재 VIN으로 보정
    final vin = ref.watch(currentVinProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sseHubProvider).switchVin(vin);
    });

    return const SizedBox.shrink();
  }
}
