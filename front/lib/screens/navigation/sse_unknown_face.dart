// lib/screens/navigation/sse_unknown_face.dart
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/scheduler.dart';               // 👈 추가: SchedulerBinding

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:moring/main.dart';                     // navigatorKey
import 'package:moring/sse/sse_hub.dart';              // SseEvent, sseHubProvider
import 'package:moring/providers/api_client.dart';     // authDioProvider
import 'package:moring/providers/car_provider.dart';   // currentVinProvider

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
      final img = (m['unauthorizedUserImgUrl'] ?? m['imageUrl'] ?? '').toString();
      final whenRaw = (m['detectedAt'] ?? m['when'] ?? '').toString();

      if (nick.isEmpty || img.isEmpty || whenRaw.isEmpty) return null;

      DateTime when = DateTime.tryParse(whenRaw)?.toLocal() ?? DateTime.now();
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
    debugPrint('[UnknownFace] got event type="$t" id="${e.id}" raw="${e.raw}"');
    if (payload == null) return;

    _showDialogNowOrNextFrame(payload);   // 👈 즉시/다음 프레임에 띄우기
  }

  // 👉 핵심: 지금 바로 루트 컨텍스트가 있으면 즉시 띄우고,
  // 없으면 프레임을 강제로 스케줄 후 다음 프레임에서 띄웁니다.
  void _showDialogNowOrNextFrame(UnknownFacePayload p) {
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      _showUnknownUserDialog(ctx, p);
      return;
    }
    // 루트 컨텍스트가 아직 없다면 프레임을 만들어준다.
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

    // Timer? autoClose;
    // autoClose = Timer(const Duration(seconds: 10), () {
    //   if (!_dialogOpen) return;
    //   final nav = Navigator.of(context, rootNavigator: true);
    //   if (nav.canPop()) nav.pop('auto');
    // });

    final result = await showGeneralDialog<String>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierLabel: '닫기',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) {
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
                      const Text('비인가 사용자 감지', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.15)),
                      const SizedBox(height: 10),
                      Text('$detectedLabel · ${p.nickname}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
                               onPressed: () => Navigator.of(context, rootNavigator: true).pop('no'),
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
                               onPressed: () => Navigator.of(context, rootNavigator: true).pop('yes'),
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

    _dialogOpen = false;
    if (myGen != _dedupGen) return;

    if (result == 'no') {
      await _sendUnauthorizedSms(p);
    } else if (result == 'yes') {
      // 페이스라인 측정 모달 띄우기
      _showFaceLineMeasurementModal(context);
    }
  }

  Future<void> _sendUnauthorizedSms(UnknownFacePayload p) async {
    try {
      final dio = ref.read(authDioProvider);
      final vin = ref.read(currentVinProvider);
      if (vin == null) return;

      await dio.post(
        '/api/v1/sms/send/unauthorized-user',
        data: {
          'vin': vin,
          'imageUrl': p.imageUrl,
          // 필요 시 'latitude','longitude' 추가
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      debugPrint('[UnknownFace] SMS sent for vin=$vin');
    } catch (e, st) {
      debugPrint('[UnknownFace] SMS send failed: $e\n$st');
    }
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
  Widget build(BuildContext context) => const SizedBox();
}