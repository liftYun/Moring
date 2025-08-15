// lib/screens/navigation/sse_only.dart
// SSE 알림 모달 + TTS 음성 읽기 (OpenAI TTS via GMS)
// 필요 .env: GMS_KEY

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:moring/providers/api_client.dart'; // authDioProvider, ensureFreshAccessToken
import 'package:moring/providers/token_repository.dart';
import 'package:moring/providers/current_car_provider.dart';

/// ===== .env =====
String get _gmsKey => dotenv.maybeGet('GMS_KEY') ?? '';

/// ===== OpenAI TTS (via GMS) =====
const _ttsUrl = 'https://gms.ssafy.io/gmsapi/api.openai.com/v1/audio/speech';
const _ttsModel = 'gpt-4o-mini-tts';
const _ttsVoice = 'nova';

class SSEAlertOverlay extends ConsumerStatefulWidget {
  /// 음성으로도 읽어줄지 여부
  final bool speakAlerts;

  /// 같은 타입 알림을 N ms 이내에는 다시 읽지 않음 (중복 방지)
  final int speakCooldownMs;

  const SSEAlertOverlay({
    super.key,
    this.speakAlerts = true,
    this.speakCooldownMs = 4000,
  });

  @override
  ConsumerState<SSEAlertOverlay> createState() => _SSEAlertOverlayState();
}

class _SSEAlertOverlayState extends ConsumerState<SSEAlertOverlay> {
  StreamSubscription<SSEModel>? _sub;
  Timer? _renewTimer;

  // 무이벤트 감시
  Timer? _watchdog;
  int _lastEventMs = 0;

  // TTS
  final _dio = Dio();
  final _player = AudioPlayer();
  bool _speaking = false;
  final Map<String, int> _lastSpoken = {}; // type -> last ms

  String? _vin;
  String? _connectUrl;
  Map<String, String> _headers = const {};

  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();

    // Android 오디오 포커스(겹침 방지)
    if (Platform.isAndroid) {
      _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.voiceCommunication,
            audioFocus: AndroidAudioFocus.gainTransientExclusive,
            isSpeakerphoneOn: true,
          ),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _prepareConnectionInfo();
      _connect();
      _renewTimer =
          Timer.periodic(const Duration(minutes: 25), (_) => _reconnect());
    });
  }

  @override
  void dispose() {
    _renewTimer?.cancel();
    _disconnect();
    _watchdog?.cancel();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  Future<void> _prepareConnectionInfo() async {
    final dio = ref.read(authDioProvider);
    final car = ref.read(currentCarProvider);
    final repo = ref.read(tokenRepositoryProvider);

    // 토큰 선제 갱신 (만료 임박 대비)
    try {
      await ensureFreshAccessToken(dio, repo, thresholdSec: 60);
    } catch (_) {}

    _vin = car?.vin;
    if (_vin == null) {
      if (!mounted) return;
      if (kDebugMode) {
        debugPrint('[SSE] VIN이 없어 연결을 시작할 수 없습니다.');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('VIN이 없어 SSE 연결을 시작할 수 없습니다.')),
      );
      return;
    }

    final base = dio.options.baseUrl;
    _connectUrl = '$base/api/v1/notifications/connect/$_vin';
    if (kDebugMode) debugPrint('[SSE] 연결 URL 준비: $_connectUrl');

    final accessToken = await repo.getAccessToken();

    _headers = {
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Accept-Encoding': 'identity',
    };
  }

  void _connect() {
    if (_connectUrl == null) return;
    _disconnect();

    if (kDebugMode) debugPrint('[SSE] 연결 시도: $_connectUrl');

    _lastEventMs = DateTime.now().millisecondsSinceEpoch;

    _sub = SSEClient.subscribeToSSE(
      url: _connectUrl!,
      header: _headers,
      method: SSERequestType.GET,
    ).listen((event) {
      _lastEventMs = DateTime.now().millisecondsSinceEpoch;

      final evt = (event.event ?? '').trim();
      final raw = (event.data ?? '').trim();

      if (kDebugMode) {
        debugPrint('[SSE] 📩 이벤트 수신: event="$evt" raw="$raw"');
      }

      // 이벤트명 우선 매칭
      final upperEvt = evt.toUpperCase();
      if (upperEvt == 'FRONT_ALERT' ||
          upperEvt == 'OXYGEN_ALERT' ||
          upperEvt == 'DISTRACTION_ALERT') {
        _handleAlert(upperEvt);
        return;
      }

      // data가 JSON이고 type이 있으면 매칭
      if (raw.isNotEmpty) {
        try {
          final m = jsonDecode(raw);
          if (m is Map && m['type'] is String) {
            final t = (m['type'] as String).toUpperCase();
            if (t == 'FRONT_ALERT' || t == 'OXYGEN_ALERT' || t == 'DISTRACTION_ALERT') {
              _handleAlert(t);
              return;
            }
          }
        } catch (_) {}
      }

      // 원시 문자열 키워드 매칭
      _handleRaw(raw, evt);
    }, onError: (e) {
      if (kDebugMode) {
        debugPrint('[SSE] 연결 오류: $e → 3초 후 재연결');
      }
      Future.delayed(const Duration(seconds: 3), _reconnect);
    }, onDone: () {
      if (kDebugMode) debugPrint('[SSE] 연결 종료됨 → 1초 후 재연결');
      Future.delayed(const Duration(seconds: 1), _reconnect);
    });

    // 무이벤트 감시 — 10초마다 체크해서 30초 이상 이벤트 없으면 재연결
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 10), (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastEventMs > 30000) {
        if (kDebugMode) debugPrint('[SSE] watchdog: no events >30s → reconnect');
        _reconnect();
      }
    });
  }

  void _reconnect() {
    _disconnect();
    _prepareConnectionInfo().then((_) => _connect());
  }

  void _disconnect() {
    _sub?.cancel();
    _sub = null;
    if (kDebugMode) debugPrint('[SSE] ⏏️ 연결 해제됨.');
  }

  void _handleRaw(String msg, String evtName) {
    if (kDebugMode) debugPrint('[Alert] 📝 원시 데이터: $msg');

    if (msg.contains('SSE 연결이 성공적으로 설정') ||
        evtName.toLowerCase() == 'connect') {
      if (kDebugMode) debugPrint('[Alert] ℹ️ 연결 성공 안내. 모달/음성 생략.');
      return;
    }

    final s = msg.replaceAll(' ', '');
    if (s.contains('전방') || s.toUpperCase().contains('FRONT_ALERT')) {
      _handleAlert('FRONT_ALERT');
    } else if (s.contains('에어컨') || s.toUpperCase().contains('OXYGEN_ALERT')) {
      _handleAlert('OXYGEN_ALERT');
    } else if (s.contains('졸음') || s.toUpperCase().contains('DISTRACTION_ALERT')) {
      _handleAlert('DISTRACTION_ALERT');
    } else {
      if (kDebugMode) {
        debugPrint('[Alert] 알 수 없는 타입: ${evtName.isEmpty ? '(no event)' : evtName}');
      }
    }
  }

  Future<void> _handleAlert(String type) async {
    if (!mounted) return;

    final up = type.toUpperCase();

    // 메시지/아이콘 매핑
    late final String title;
    late final String message;
    late final IconData icon;
    switch (up) {
      case 'FRONT_ALERT':
        title = '경고';
        message = '전방을 주시하십시오.';
        icon = Icons.warning_amber_rounded;
        break;
      case 'OXYGEN_ALERT':
        title = '주의';
        message = '졸음 조심! 에어컨을 가동합니다.';
        icon = Icons.ac_unit;
        break;
      case 'DISTRACTION_ALERT':
        title = '주의';
        message = '졸음 조심!';
        icon = Icons.visibility_off;
        break;
      default:
        return;
    }

    // 모달 띄우기 (중복 방지: 이미 떠 있으면 스킵)
    if (!_dialogOpen) {
      _dialogOpen = true;
      unawaited(_autoCloseDialogAfter(const Duration(seconds: 5)));
      unawaited(_showAlertDialog(title: title, message: message, icon: icon));
    }

    // 음성 읽기 (중복/도배 방지)
    if (widget.speakAlerts) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final last = _lastSpoken[up] ?? 0;
      if (now - last >= widget.speakCooldownMs) {
        _lastSpoken[up] = now;
        unawaited(_speak(message));
      } else {
        if (kDebugMode) debugPrint('[TTS] $up 최근 ${widget.speakCooldownMs}ms 내 재생됨 → 스킵');
      }
    }
  }

  Future<void> _autoCloseDialogAfter(Duration d) async {
    await Future.delayed(d);
    if (mounted && _dialogOpen) {
      if (kDebugMode) debugPrint('[Alert] ⏱ 자동 닫힘(${d.inSeconds}s)');
      Navigator.of(context, rootNavigator: true).maybePop('auto');
      _dialogOpen = false;
    }
  }

  Future<void> _showAlertDialog({
    required String title,
    required String message,
    required IconData icon,
  }) async {
    if (!mounted) return;
    if (kDebugMode) debugPrint('[Alert] ✅ 모달 표시: $title / $message');

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '닫기',
      barrierColor: Colors.black.withOpacity(0.35),
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
                    boxShadow: const [
                      BoxShadow(blurRadius: 18, color: Colors.black26, offset: Offset(0, 8)),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: Colors.lightBlueAccent, size: 34),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              message,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 80, left: 18, right: 18),
            child: Opacity(
              opacity: anim1.value,
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
                      boxShadow: const [
                        BoxShadow(blurRadius: 18, color: Colors.black26, offset: Offset(0, 8)),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: Colors.lightBlueAccent, size: 34),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                message,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _dialogOpen = false;
  }

  /// ====== TTS ======
  Future<void> _speak(String text) async {
    if (_gmsKey.isEmpty) {
      if (kDebugMode) debugPrint('[TTS] GMS_KEY 미설정');
      return;
    }
    if (text.trim().isEmpty) return;

    try {
      // 이미 재생 중이면 끊고 새로 읽기 (알림 우선)
      if (_speaking) {
        await _player.stop();
        _speaking = false;
      }

      final body = {
        'model': _ttsModel,
        'input': text,
        'voice': _ttsVoice,
        'response_format': 'mp3',
      };

      final res = await _dio.post(
        _ttsUrl,
        data: jsonEncode(body),
        options: Options(
          headers: {
            'Authorization': 'Bearer $_gmsKey',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.bytes,
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if (res.statusCode == 200 && res.data != null) {
        final bytes = Uint8List.fromList(res.data as List<int>);
        _speaking = true;
        await _player.play(BytesSource(bytes));
      } else {
        if (kDebugMode) debugPrint('[TTS] 실패 status=${res.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[TTS] 예외: $e');
    } finally {
      _speaking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 화면에는 아무것도 그리지 않음(오버레이 역할)
    return const SizedBox.shrink();
  }
}
