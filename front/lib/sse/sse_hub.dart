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
  Timer? _reconnectTimer; // 단일 재접속 타이머
  int _retry = 0; // 지수 백오프 카운터
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
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _retry = 0; // 완전 단절 시 백오프 초기화
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
      // 1) 연결 직전 토큰 신선도 보장
      await _ensureFreshToken();
      // final at = await repo.getAccessToken();
      // ✅ 연결 직전, authDio의 선제 리프레시 로직 재사용
      // 만료 60초 이내면 /auth/refresh 호출하여 AT 교체
      await ensureFreshAccessToken(dio, repo, thresholdSec: 60);
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
      // ).listen(_onData, onError: (e, st) {
      //   if (kDebugMode) {
      //     debugPrint('[SSEHub] ✖ onError: $e');
      //   }
      //   // _scheduleReconnect(const Duration(seconds: 2));
      //   _scheduleReconnect();
      // }, onDone: () {
      //   if (kDebugMode) {
      //     debugPrint('[SSEHub] ⏹ done → reconnect(1s)');
      //   }
      //   // _scheduleReconnect(const Duration(seconds: 1));
      //   _scheduleReconnect();
      // });
      ).listen(_onData, onError: (e, st) async {
        if (kDebugMode) debugPrint('[SSEHub] ✖ onError: $e');
        // 401/만료로 끊긴 케이스 힌트가 있으면 즉시 리프레시 시도
        final msg = e.toString().toLowerCase();
        if (msg.contains('401') || msg.contains('expired')) {
          try {
            await ensureFreshAccessToken(dio, repo, thresholdSec: 3600);
          } catch (_) {/* ignore */}
        }
        _scheduleReconnect();
        }, onDone: () {
        if (kDebugMode) debugPrint('[SSEHub] ⏹ done → reconnect');
        _scheduleReconnect();
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
      // _scheduleReconnect(const Duration(seconds: 3));
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  // void _scheduleReconnect(Duration delay) {
  //   // 중복 reconnect 방지
  //   Future.delayed(delay, () {
  //     if (_disposed) return;
  //     reconnect();
  //   });
  // }
  void _scheduleReconnect() {
      if (_disposed) return;
      // 이미 예약된 재접속 있으면 중복 금지
      if (_reconnectTimer != null) return;
      // 지수 백오프: 1s → 2s → 4s ... 최대 30s + 약간의 지터(0~500ms)
      final baseMs = (1000 * (1 << _retry)).clamp(1000, 30000);
      final jitter = (DateTime.now().microsecondsSinceEpoch % 500);
      final delay = Duration(milliseconds: baseMs + jitter);
      if (kDebugMode) {
        debugPrint('[SSEHub] ⟳ schedule reconnect in ${delay.inMilliseconds}ms (retry=$_retry)');
      }
      _reconnectTimer = Timer(delay, () async {
        _reconnectTimer = null;
        if (_disposed) return;
        _retry = (_retry + 1).clamp(0, 10);
        await reconnect();
      });
  }

  Future<void> _onData(SSEModel m) async {
    _lastEventMs = DateTime.now().millisecondsSinceEpoch;
    _retry = 0; // 데이터 수신되면 백오프 리셋

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
    }// 2) 서버가 만료를 JSON으로 보낸 경우 감지 → refresh & 재연결
    // ✅ 서버가 에러 JSON으로 만료를 흘리는 경우: 즉시 리프레시 재사용
    try {
      if (raw.isNotEmpty) {
        final maybe = jsonDecode(raw);
        if (maybe is Map<String, dynamic>) {
          final err = (maybe['error'] ?? '').toString().toLowerCase();
          if (err.contains('access token expired') || err.contains('token expired') || err.contains('jwt expired')) {
            final dio = _ref.read(authDioProvider);
            final repo = _ref.read(tokenRepositoryProvider);
            try { await ensureFreshAccessToken(dio, repo, thresholdSec: 3600); } catch (_) {}
            await reconnect();
            return;
          }
        }
      }
    } catch (_) {}

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
  // === 토큰 신선도 보장 ===
  Future<void> _ensureFreshToken() async {
    final repo = _ref.read(tokenRepositoryProvider);
    final at = await repo.getAccessToken();
    final expSec = _tryDecodeExp(at);
    if (expSec == null) return; // 모를 땐 일단 진행
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // 만료 30초 전이면 갱신
    if (expSec - nowSec < 30) {
      final ok = await _tryRefresh();
      if (!ok) throw Exception('TOKEN_REFRESH_FAILED');
    }
  }

  int? _tryDecodeExp(String? jwt) {
    if (jwt == null || jwt.split('.').length != 3) return null;
    try {
      final payload = base64Url.normalize(jwt.split('.')[1]);
      final map = jsonDecode(utf8.decode(base64Url.decode(payload)));
      final exp = map['exp'];
      if (exp is int) return exp;
      if (exp is String) return int.tryParse(exp);
        return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleExpiredToken() async {
    final ok = await _tryRefresh();
    if (ok) {
      _retry = 0;
      await reconnect();
    } else {
      // 앱 정책에 맞게 처리
      if (kDebugMode) debugPrint('[SSEHub] ❌ refresh failed → stop auto-reconnect');
      await _disconnect();
      // TODO: 전역 auth 상태 갱신/로그아웃 라우팅이 있다면 호출
    }
  }

  Future<bool> _tryRefresh() async {
    try {
      final repo = _ref.read(tokenRepositoryProvider);
      final dio  = _ref.read(authDioProvider);

      final rt = await repo.getRefreshToken();
      if (rt == null || rt.isEmpty) {
        if (kDebugMode) debugPrint('[SSEHub] no refresh token');
        return false;
      }

      final resp = await dio.post(
        '/api/v1/auth/refresh',
        options: Options(
          headers: {'Cookie': 'refreshToken=$rt'},
          // refresh 요청은 인터셉터의 선제리프레시/Authorization을 건너뜀
          extra: {'skipAuth': true, 'skipPreRefresh': true},
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if (resp.statusCode == 200) {
        final newAt = resp.data['accessToken'] as String?;
        final newRt = resp.data['refreshToken'] as String?;
        if (newAt != null && newAt.isNotEmpty) {
          await repo.saveAccessToken(newAt);
        }
        if (newRt != null && newRt.isNotEmpty) {
          await repo.saveRefreshToken(newRt);
        }
        if (kDebugMode) debugPrint('[SSEHub] token refresh OK');
        return true;
      } else {
        if (kDebugMode) {
          debugPrint('[SSEHub] token refresh failed: ${resp.statusCode}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[SSEHub] refresh error: $e');
      return false;
    }
  }
}
