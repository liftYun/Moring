// lib/sse/sse_hub.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import 'package:moring/providers/api_client.dart';           // authDioProvider
import 'package:moring/providers/token_repository.dart';      // tokenRepositoryProvider
import 'package:moring/providers/car_provider.dart';          // currentVinProvider

/// 외부 위젯에서 구독할 수 있는 이벤트 모델
class SseEvent {
  final String id;
  final String event;     // event: 이름 (대문자)
  final String dataRaw;   // data: 원문 문자열
  final Map<String, dynamic>? json;

  SseEvent({
    required this.id,
    required this.event,
    required this.dataRaw,
    required this.json,
  });
}

/// 전역 허브 프로바이더
final sseHubProvider = Provider<SseHub>((ref) {
  final hub = SseHub(ref);
  ref.onDispose(hub.dispose);
  return hub;
});

/// 단일 SSE 연결을 전역에서 관리
class SseHub {
  final Ref ref;
  SseHub(this.ref);

  // 상태
  String? _vin;                          // 현재 연결된 VIN
  StreamSubscription<SSEModel>? _sub;
  Timer? _renewTimer;                    // 25분마다 재연결
  Timer? _watchdog;                      // 30초 무이벤트시 재연결
  int _lastEventMs = 0;

  // 브로드캐스트 스트림
  final _controller = StreamController<SseEvent>.broadcast();
  Stream<SseEvent> get stream => _controller.stream;

  bool get isConnected => _sub != null;

  /// 외부(부트스트랩/페이지)에서 최초 1회 보장 호출용.
  /// VIN이 없으면 아무 것도 안함.
  Future<void> ensureConnected() async {
    if (_vin == null) return;
    if (isConnected) return;
    await _connect(_vin!);
  }

  /// VIN 변경 시 호출. null이면 연결 해제만 수행.
  Future<void> switchVin(String? newVin) async {
    if (_vin == newVin) return;

    final oldVin = _vin;
    _vin = newVin;

    // 서버 disconnect 호출 (이전 VIN이 있을 때만)
    if (oldVin != null) {
      _fireAndForgetServerDisconnect(oldVin);
    }

    // 로컬 소켓 정리
    _disconnect();

    // 새 VIN으로 연결
    if (newVin != null) {
      await _connect(newVin);
    }
  }

  /// 앱 종료/로그아웃 시
  Future<void> disconnectAll() async {
    final oldVin = _vin;
    _vin = null;
    _disconnect();
    if (oldVin != null) {
      _fireAndForgetServerDisconnect(oldVin);
    }
  }

  void dispose() {
    _disconnect();
    _controller.close();
  }

  // ================= 내부 구현 =================

  Future<void> _connect(String vin) async {
    // 토큰/URL 준비
    final dio = ref.read(authDioProvider);
    final repo = ref.read(tokenRepositoryProvider);

    final base = dio.options.baseUrl;
    final url = '$base/api/v1/notifications/connect/$vin';

    final accessToken = await repo.getAccessToken();
    if (kDebugMode) {
      debugPrint('[SSEHub] connect → $url (AT? ${accessToken != null})');
    }

    final headers = <String, String>{
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Accept-Encoding': 'identity',
    };

    _lastEventMs = DateTime.now().millisecondsSinceEpoch;

    // 기존 구독 정리
    _sub?.cancel();
    _sub = SSEClient.subscribeToSSE(
      url: url,
      header: headers,
      method: SSERequestType.GET,
    ).listen((evt) {
      _lastEventMs = DateTime.now().millisecondsSinceEpoch;

      final id = (evt.id ?? '').trim();
      final name = (evt.event ?? '').trim();
      final raw = (evt.data ?? '').trim();

      Map<String, dynamic>? json;
      if (raw.isNotEmpty) {
        try {
          final parsed = jsonDecode(raw);
          if (parsed is Map<String, dynamic>) json = parsed;
        } catch (_) {}
      }

      final upperName = name.isNotEmpty
          ? name.toUpperCase()
          : (json?['type'] is String ? (json!['type'] as String).toUpperCase() : '');

      if (kDebugMode) {
        debugPrint('[SSEHub] ⇦ event="$upperName" id="$id" raw="${raw.length > 200 ? raw.substring(0, 200) + '…' : raw}"');
      }

      _controller.add(SseEvent(id: id, event: upperName, dataRaw: raw, json: json));
    }, onError: (e) {
      if (kDebugMode) debugPrint('[SSEHub] error: $e → reconnect in 3s');
      Future.delayed(const Duration(seconds: 3), _reconnect);
    }, onDone: () {
      if (kDebugMode) debugPrint('[SSEHub] done → reconnect in 1s');
      Future.delayed(const Duration(seconds: 1), _reconnect);
    });

    // 25분 주기 재연결
    _renewTimer?.cancel();
    _renewTimer = Timer.periodic(const Duration(minutes: 25), (_) => _reconnect());

    // 10초마다 무이벤트 검사 -> 30초 이상이면 재연결
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 10), (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastEventMs > 20000) {
        if (kDebugMode) debugPrint('[SSEHub] watchdog: no events >20s → reconnect');
        _reconnect();
      }
    });
  }

  void _reconnect() {
    if (_vin == null) return;
    _disconnect();
    _connect(_vin!); // ignore: discarded_futures
  }

  void _disconnect() {
    _sub?.cancel();
    _sub = null;
    _renewTimer?.cancel();
    _renewTimer = null;
    _watchdog?.cancel();
    _watchdog = null;
    if (kDebugMode) debugPrint('[SSEHub] ⏏ disconnect (vin=$_vin)');
  }

  /// 서버에 명시적으로 끊기 요청(실패해도 무시)
  void _fireAndForgetServerDisconnect(String vin) {
    // authDioProvider 사용(AT 자동첨부용 인터셉터)
    final dio = ref.read(authDioProvider);
    dio.delete('/api/v1/notifications/disconnect/$vin',
        options: Options(validateStatus: (s) => s != null && s < 500))
        .then((_) {
      if (kDebugMode) debugPrint('[SSEHub] server disconnect OK for $vin');
    }).catchError((e) {
      if (kDebugMode) debugPrint('[SSEHub] server disconnect failed: $e');
    });
  }
}
