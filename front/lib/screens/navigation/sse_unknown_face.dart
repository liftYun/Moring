// lib/screens/navigation/sse_unknown_face.dart
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:moring/sse/sse_hub.dart';
import 'package:moring/providers/api_client.dart';      // authDioProvider
import 'package:moring/main.dart';                      // navigatorKey

class UnknownFacePayload {
  final DateTime? time;
  final String? imageUrl;
  final String? carNickname;
  final String? vin;

  UnknownFacePayload({this.time, this.imageUrl, this.carNickname, this.vin});

  factory UnknownFacePayload.fromAny(dynamic data) {
    Map m;
    if (data is Map) {
      m = data;
    } else if (data is String) {
      try { m = (jsonDecode(data) as Map); } catch (_) { m = {}; }
    } else {
      m = {};
    }

    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return null;
    }

    DateTime? parseTime() {
      final s = pick(['createdAt','timestamp','ts','time','dateTime']);
      if (s == null) return null;
      try { return DateTime.parse(s); } catch (_) { return null; }
    }

    return UnknownFacePayload(
      time: parseTime(),
      imageUrl: pick(['imageUrl','img','image_url','faceImageUrl','photoUrl']),
      carNickname: pick(['carNickname','carName','car_nickname','vehicleNickname']),
      vin: pick(['vin','carVin','vehicleVin']),
    );
  }
}

class UnknownFaceSSEOverlay extends ConsumerStatefulWidget {
  final bool speak;
  final int dedupWindowMs; // 같은 이미지/이벤트  중복 방지
  const UnknownFaceSSEOverlay({super.key, this.speak = true, this.dedupWindowMs = 15000});

  @override
  ConsumerState<UnknownFaceSSEOverlay> createState() => _UnknownFaceSSEOverlayState();
}

class _UnknownFaceSSEOverlayState extends ConsumerState<UnknownFaceSSEOverlay> {
  StreamSubscription<SseEvent>? _sub;
  bool _modalOpen = false;

  // 디듑
  String? _lastKey;
  int _lastShownMs = 0;

  @override
  void initState() {
    super.initState();
    // 허브 연결 보장
    ref.read(sseHubProvider).ensureConnected();
    _sub = ref.read(sseHubProvider).stream.listen(_onEvent);
  }

  void _onEvent(SseEvent e) {
    final type = _extractType(e);
    if (type != 'UNKNOWN_FACE' && type != 'UNKNOWN_FACE_DETECTED') return;

    final payload = UnknownFacePayload.fromAny(e.json ?? e.dataRaw);
    if (payload.imageUrl == null) return;

    // dedup key: imageUrl + time
    final key = '${payload.imageUrl}|${payload.time?.toIso8601String() ?? ''}';
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastKey == key && now - _lastShownMs < widget.dedupWindowMs) {
      if (kDebugMode) debugPrint('[UnknownFace] dedup drop');
      return;
    }
    _lastKey = key;
    _lastShownMs = now;

    _showModal(payload);
  }

  String _extractType(SseEvent e) {
    final dataType = (e.json?['type'] ?? '').toString().toUpperCase();
    final evt = e.event.toUpperCase();
    if (evt.contains('UNKNOWN_FACE')) return 'UNKNOWN_FACE';
    if (evt.contains('UNKNOWN_FACE_DETECTED')) return 'UNKNOWN_FACE_DETECTED';
    return dataType;
  }

  Future<void> _showModal(UnknownFacePayload p) async {
    if (!mounted || _modalOpen) return;
    _modalOpen = true;

    final tsText = p.time != null
        ? '${p.time!.toLocal()}'.replaceFirst('.000', '')
        : '시간 정보 없음';
    final carName = p.carNickname ?? '차량';

    final result = await showDialog<String>(
      context: navigatorKey.currentContext!,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('미등록 사용자 감지'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (p.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(p.imageUrl!, fit: BoxFit.cover),
                ),
              const SizedBox(height: 12),
              Text('$carName 에 등록된 사용자가 아닙니다.'),
              const SizedBox(height: 6),
              Text('감지 시각: $tsText', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              const Text('등록하시겠습니까?'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, 'no'), child: const Text('아니요')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, 'yes'), child: const Text('네')),
          ],
        );
      },
    );

    _modalOpen = false;

    if (result == 'yes') {
      _handleYesRegister(p);
    } else if (result == 'no') {
      _handleNoSendSms(p);
    }
  }

  Future<void> _handleYesRegister(UnknownFacePayload p) async {
    navigatorKey.currentState?.pushNamed('/registration');
  }

  Future<void> _handleNoSendSms(UnknownFacePayload p) async {
    try {
      final dio = ref.read(authDioProvider);
      await dio.post(
        '/api/v1/sms/send/unauthorized-user',
        data: {
          'vin': p.vin,
          'imageUrl': p.imageUrl,
          'detectedAt': p.time?.toUtc().toIso8601String(),
          'carNickname': p.carNickname,
        },
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
    } catch (e) {
      debugPrint('[UnknownFace] SMS 전송 실패: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
