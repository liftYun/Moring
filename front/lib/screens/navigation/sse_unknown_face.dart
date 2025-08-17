// lib/screens/navigation/sse_unknown_face.dart
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/scheduler.dart';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:moring/main.dart';                   // navigatorKey
import 'package:moring/sse/sse_hub.dart';            // SseEvent, sseHubProvider
import 'package:moring/providers/api_client.dart';   // authDioProvider
import 'package:moring/providers/car_provider.dart'; // currentVinProvider

// ======================= Payload =======================

class UnknownFacePayload {
  final String nickname;      // 차량 닉네임
  final DateTime detectedAt;  // 감지 시각
  final String imageUrl;      // 이미지 URL

  UnknownFacePayload({
    required this.nickname,
    required this.detectedAt,
    required this.imageUrl,
  });

  static UnknownFacePayload? fromAny(dynamic any) {
    try {
      final Map<String, dynamic> m = any is String
          ? jsonDecode(any) as Map<String, dynamic>
          : (any as Map).cast<String, dynamic>();

      final nick = (m['nickname'] ?? m['nickName'] ?? '').toString();
      final img  = (m['unauthorizedUserImgUrl'] ?? m['imageUrl'] ?? '').toString();
      final whenRaw = (m['detectedAt'] ?? m['when'] ?? '').toString();

      if (nick.isEmpty || img.isEmpty || whenRaw.isEmpty) return null;

      final when = DateTime.tryParse(whenRaw)?.toLocal() ?? DateTime.now();
      return UnknownFacePayload(nickname: nick, detectedAt: when, imageUrl: img);
    } catch (_) {
      return null;
    }
  }
}

// ======================= Overlay =======================

class UnknownFaceSSEOverlay extends ConsumerStatefulWidget {
  const UnknownFaceSSEOverlay({super.key});
  @override
  ConsumerState<UnknownFaceSSEOverlay> createState() => _UnknownFaceSSEOverlayState();
}

class _UnknownFaceSSEOverlayState extends ConsumerState<UnknownFaceSSEOverlay> {
  StreamSubscription<SseEvent>? _sub;
  bool _dialogOpen = false;
  int _dedupGen = 0;

  @override
  void initState() {
    super.initState();
    final hub = ref.read(sseHubProvider);
    hub.ensureConnected();
    _sub = hub.stream.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onEvent(SseEvent e) {
    final t = (e.event.isNotEmpty ? e.event : (e.json?['type'] ?? '').toString()).toUpperCase();
    if (t != 'UNAUTHORIZED_USER_DETECTED') return;

    final payload = UnknownFacePayload.fromAny(e.json ?? e.raw);
    debugPrint('[UnknownFace] event="$t" id=${e.id} payload? ${payload != null}');
    if (payload == null) return;

    _showDialogNowOrNextFrame(payload);
  }

  // 루트 컨텍스트가 있으면 즉시, 없으면 다음 프레임에서 띄우기
  void _showDialogNowOrNextFrame(UnknownFacePayload p) {
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      _showUnknownUserDialog(ctx, p);
      return;
    }
    SchedulerBinding.instance.scheduleFrame();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final c = navigatorKey.currentContext;
      if (c != null) _showUnknownUserDialog(c, p);
    });
  }

  Future<void> _showUnknownUserDialog(BuildContext context, UnknownFacePayload p) async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    final myGen = ++_dedupGen;

    final detectedLabel =
        '${p.detectedAt.year}-${_2(p.detectedAt.month)}-${_2(p.detectedAt.day)} '
        '${_2(p.detectedAt.hour)}:${_2(p.detectedAt.minute)}:${_2(p.detectedAt.second)}';

    // === 카운트다운/자동닫힘 (180s) ===
    final secondsLeft = ValueNotifier<int>(180);
    final countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsLeft.value > 0) secondsLeft.value = secondsLeft.value - 1;
      if (secondsLeft.value <= 0 && _dialogOpen) {
        Navigator.of(context, rootNavigator: true).maybePop('timeout');
      }
    });

    final result = await showGeneralDialog<String>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierLabel: '닫기',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) {
        bool sending = false;

        // 버튼 공통 처리
        Future<void> onAnswer({required bool authorized}) async {
          if (sending) return;
          sending = true;

          // PATCH는 스펙: /api/v1/cars/{vin}/unauthorized-driver-popup?showPopup=bool
          try {
            await _updateUnauthorizedPopup(showPopup: authorized);
            debugPrint('[UnknownFace] PATCH ok (showPopup=$authorized)');
          } catch (e, st) {
            debugPrint('[UnknownFace] PATCH failed: $e\n$st');
          }

          // "아니요(무단)"이면 PATCH 성공/실패와 관계없이 SMS는 반드시 시도
          if (!authorized) {
            try {
              await _sendUnauthorizedSms(p);
              debugPrint('[UnknownFace] SMS sent');
            } catch (e, st) {
              debugPrint('[UnknownFace] SMS failed: $e\n$st');
            }
          }

          if (_dialogOpen) {
            Navigator.of(context, rootNavigator: true).pop(authorized ? 'yes' : 'no');
          }
        }

        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 80, left: 18, right: 18),
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 280, maxWidth: 640),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF232326).withOpacity(0.94),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                    boxShadow: const [BoxShadow(blurRadius: 18, color: Colors.black26, offset: Offset(0, 8))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('비인가 사용자 감지',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.15)),
                      const SizedBox(height: 10),
                      Text('$detectedLabel · ${p.nickname}',
                          style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      ValueListenableBuilder<int>(
                        valueListenable: secondsLeft,
                        builder: (_, s, __) => Text(
                          '자동으로 닫힘: ${s}s',
                          style: const TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(
                            p.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.black26,
                              alignment: Alignment.center,
                              child: const Text('이미지를 불러오지 못했습니다', style: TextStyle(color: Colors.white54)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('등록된 사용자가 아닙니다. 등록하시겠습니까?', style: TextStyle(color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 80,
                            height: 36,
                            child: OutlinedButton(
                              onPressed: () => onAnswer(authorized: false), // ❌ 무단 → PATCH(false) + SMS(항상)
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF50C878),
                                side: const BorderSide(color: Color(0xFF50C878), width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text('아니요'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            height: 36,
                            child: ElevatedButton(
                              onPressed: () => onAnswer(authorized: true), // ✅ 인가 → PATCH(true)
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF50C878),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text('네'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    // 정리
    countdown.cancel();
    _dialogOpen = false;
    if (myGen != _dedupGen) return;

    debugPrint('[UnknownFace] dialog result=$result');

    if (result == 'no') {
      // 이미 onAnswer()에서 SMS 시도함 — 여기선 추가 조치 없음.
    } else if (result == 'yes') {
      // 인가 선택 시: 페이스라인 측정 모달 띄우기 (v2 기능 유지)
      _showFaceLineMeasurementModal(context);
    }
  }

  // 서버 팝업 상태 업데이트 (스펙: showPopup 쿼리 파라미터)
  Future<void> _updateUnauthorizedPopup({required bool showPopup}) async {
    final dio = ref.read(authDioProvider);
    final vin = ref.read(currentVinProvider);
    if (vin == null) throw Exception('VIN is null');

    await dio.patch(
      '/api/v1/cars/$vin/unauthorized-driver-popup',
      queryParameters: {
        'showPopup': showPopup, // true: 인가됨, false: 무단
      },
      options: Options(headers: {'Content-Type': 'application/json'}),
      // body는 없음
    );
  }

  // 무단 운전자 SMS 발송 (아니요 클릭 시 항상 시도)
  Future<void> _sendUnauthorizedSms(UnknownFacePayload p) async {
    final dio = ref.read(authDioProvider);
    final vin = ref.read(currentVinProvider);
    if (vin == null) throw Exception('VIN is null');

    await dio.post(
      '/api/v1/sms/send/unauthorized-user',
      data: {
        'vin': vin,
        'imageUrl': p.imageUrl,
      },
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
  }

  /// 🆕 페이스라인 측정 모달 띄우기
  void _showFaceLineMeasurementModal(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showModalBottomSheet(
        context: context,
        barrierColor: Colors.black.withOpacity(0.3),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) {
          return Stack(
            children: [
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(color: Colors.transparent),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 220,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF23262B),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 24,
                        offset: Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '10분간 페이스라인 측정 예정입니다.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '얼굴을 가리지 말고 운전해 주십시오.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '(해당 시간 동안 일부 기능이 제한될 수 있습니다.)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.24),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context); // 모달 닫기
                          },
                          child: const Text(
                            '확인',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );
    });
  }

  String _2(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
