// lib/sse/sse_hub.dart
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';

import 'package:moring/providers/api_client.dart'; // authDioProvider
import 'package:moring/providers/token_repository.dart'; // tokenRepositoryProvider

/// 외부에 노출되는 SSE 이벤트 표준 형태
class SseEvent {
  final String event;
  final String id;
  final String raw; // 원문 data
  final Map<String, dynamic>? json; // data를 JSON으로 파싱한 결과(가능하면)

  SseEvent({
    required this.event,
    required this.id,
    required this.raw,
    required this.json,
  });

  @override
  String toString() =>
      'SseEvent(event="$event" id="$id" raw="$raw" json=${json != null ? 'Y' : 'N'})';
}

/// 허브 Provider
final sseHubProvider = Provider<SSEHub>((ref) {
  return SSEHub(ref);
});

/// 앱 전역에서 소켓 1개만 유지하는 허브
class SSEHub {
  SSEHub(this._ref);

  final Ref _ref;

  String? _vin;
  StreamSubscription<SSEModel>? _sub;

  final _ctrl = StreamController<SseEvent>.broadcast();
  Stream<SseEvent> get stream => _ctrl.stream;

  Timer? _renewTimer; // 25분 주기 재연결
  Timer? _watchdog;   // 30초 무이벤트 감시
  int _lastEventMs = 0;

  bool _connecting = false;
  bool _disposed = false;

  /// 외부에서 VIN 바뀔 때 호출 (SseBootstrap이 사용)
  Future<void> switchVin(String? vin) async {
    if (_disposed) return;
    final changed = _vin != vin;
    _vin = vin;

    if (changed) {
      await reconnect();
    } else {
      // VIN 같아도 아직 연결이 없으면 보장
      if (_sub == null) {
        await ensureConnected();
      }
    }
  }

  /// 소켓 연결 보장 (VIN이 있어야 시도)
  Future<void> ensureConnected() async {
    if (_disposed || _connecting || _sub != null) return;
    if (_vin == null || _vin!.isEmpty) return; // VIN 없으면 대기

    await _connect();
  }

  /// 수동 재연결
  Future<void> reconnect() async {
    await _disconnect();
    await ensureConnected();
  }

  Future<void> _disconnect() async {
    await _sub?.cancel();
    _sub = null;
    _renewTimer?.cancel();
    _renewTimer = null;
    _watchdog?.cancel();
    _watchdog = null;
  }

  Future<void> _connect() async {
    if (_connecting || _sub != null) return;
    if (_vin == null || _vin!.isEmpty) return;
    _connecting = true;

    try {
      final dio = _ref.read(authDioProvider);
      final repo = _ref.read(tokenRepositoryProvider);

      final base = dio.options.baseUrl;
      final vin = _vin!;
      final url = '$base/api/v1/notifications/connect/$vin';
      final at = await repo.getAccessToken();

      final headers = <String, String>{
        if (at != null) 'Authorization': 'Bearer $at',
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
        'Accept-Encoding': 'identity',
      };

      if (kDebugMode) {
        debugPrint('[SSEHub] ⛓ connect url=$url (vin=$vin)');
      }

      _lastEventMs = DateTime.now().millisecondsSinceEpoch;

      _sub = SSEClient.subscribeToSSE(
        url: url,
        header: headers,
        method: SSERequestType.GET,
      ).listen(_onData, onError: (e, st) {
        if (kDebugMode) {
          debugPrint('[SSEHub] ✖ onError: $e');
        }
        _scheduleReconnect(const Duration(seconds: 2));
      }, onDone: () {
        if (kDebugMode) {
          debugPrint('[SSEHub] ⏹ done → reconnect(1s)');
        }
        _scheduleReconnect(const Duration(seconds: 1));
      });

      // 25분마다 재연결 (리버스 프록시/백엔드 타임아웃 회피)
      _renewTimer?.cancel();
      _renewTimer = Timer.periodic(const Duration(minutes: 25), (_) {
        if (kDebugMode) debugPrint('[SSEHub] ♻ renew timer → reconnect');
        reconnect();
      });

      // 30초 무이벤트 watchdog
      _watchdog?.cancel();
      _watchdog = Timer.periodic(const Duration(seconds: 10), (_) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastEventMs > 30000) {
          if (kDebugMode) {
            debugPrint('[SSEHub] 🐶 watchdog (>30s no events) → reconnect');
          }
          reconnect();
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SSEHub] connect() error: $e');
      }
      _scheduleReconnect(const Duration(seconds: 3));
    } finally {
      _connecting = false;
    }
  }

  void _scheduleReconnect(Duration delay) {
    // 중복 reconnect 방지
    Future.delayed(delay, () {
      if (_disposed) return;
      reconnect();
    });
  }

  void _onData(SSEModel m) {
    _lastEventMs = DateTime.now().millisecondsSinceEpoch;

    final event = (m.event ?? '').trim();
    final id = (m.id ?? '').trim();
    final raw = (m.data ?? '').trim();

    if (kDebugMode) {
      debugPrint('[SSEHub] ⇦ event="$event" id="$id" raw="$raw"');
    }

    // ping/연결안내 무시(필요하면 스트림으로 흘려보내도 OK)
    if (event.toUpperCase() == 'PING' || raw == '💓') {
      return;
    }
    if (raw.contains('SSE 연결이 성공적으로 설정')) {
      return;
    }

    Map<String, dynamic>? js;
    if (raw.isNotEmpty) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map<String, dynamic>) {
          js = parsed;
        }
      } catch (_) {}
    }

    final evType = event.isNotEmpty
        ? event
        : (js?['type'] is String ? (js!['type'] as String) : '');

    _ctrl.add(
      SseEvent(
        event: evType,
        id: id,
        raw: raw,
        json: js,
      ),
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    await _disconnect();
    await _ctrl.close();
  }
}
