// lib/screens/navigation/sse_only.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:moring/sse/sse_hub.dart';

/// .env
String get _gmsKey => dotenv.maybeGet('GMS_KEY') ?? '';

/// OpenAI(GMS 프록시) TTS
const _ttsUrl = 'https://gms.ssafy.io/gmsapi/api.openai.com/v1/audio/speech';
const _ttsModel = 'gpt-4o-mini-tts';
const _ttsVoice = 'nova';

class SSEAlertOverlay extends ConsumerStatefulWidget {
  /// 알림을 음성으로도 안내할지
  final bool speak;

  /// 같은 타입 알림에 대해 몇 ms 이내 재낭독을 막을지(디듑)
  final int speechDedupMs;

  const SSEAlertOverlay({
    super.key,
    this.speak = true,
    this.speechDedupMs = 5000,
  });

  @override
  ConsumerState<SSEAlertOverlay> createState() => _SSEAlertOverlayState();
}

class _SSEAlertOverlayState extends ConsumerState<SSEAlertOverlay> {
  StreamSubscription<SseEvent>? _sub;
  bool _dialogOpen = false;

  // ===== TTS 관련 =====
  final _dio = Dio();
  final _player = AudioPlayer();

  // 낭독 디듑 (타입별 최근 낭독시각)
  final Map<String, int> _lastSpeakAt = {};

  @override
  void initState() {
    super.initState();

    // 허브 연결 보장 (소켓 1개만)
    ref.read(sseHubProvider).ensureConnected();

    // 이벤트 구독
    _sub = ref.read(sseHubProvider).stream.listen(_onEvent);

    // Android 오디오 포커스(스피커폰)
    _configureAudioContext();
  }

  Future<void> _configureAudioContext() async {
    if (Theme.of(context).platform == TargetPlatform.android) {
      await _player.setAudioContext(
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
  }

  void _onEvent(SseEvent e) {
    // 타입 판별: event 이름 또는 data.type
    final type = _extractType(e).toUpperCase();

    if (type == 'FRONT_ALERT' ||
        type == 'OXYGEN_ALERT' ||
        type == 'DISTRACTION_ALERT') {
      _showAlert(type);
      if (widget.speak) {
        _speakAlert(type); // TTS
      }
    }
  }

  String _extractType(SseEvent e) {
    if (e.event.isNotEmpty) return e.event;
    final t = e.json?['type'];
    return (t is String ? t : '').toUpperCase();
  }

  Future<void> _showAlert(String type) async {
    if (!mounted || _dialogOpen) return;
    _dialogOpen = true;

    String title = '알림';
    String message = '';
    IconData icon = Icons.notifications_active;

    switch (type) {
      case 'FRONT_ALERT':
        title = '경고';
        message = '전방을 주시하십시오.';
        icon = Icons.warning_amber_rounded;
        break;
      case 'OXYGEN_ALERT':
        title = '주의';
        message = '졸음 조심!! 에어컨 가동';
        icon = Icons.ac_unit;
        break;
      case 'DISTRACTION_ALERT':
        title = '주의';
        message = '졸음 조심!!';
        icon = Icons.visibility_off;
        break;
    }

    // 자동 닫힘 5초
    final autoClose = Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _dialogOpen) {
        Navigator.of(context, rootNavigator: true).maybePop('auto');
      }
    });

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '닫기',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) {
        return const SizedBox.shrink(); // transitionBuilder에서 렌더링
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
                  constraints:
                  const BoxConstraints(minWidth: 280, maxWidth: 640),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 22),
                    decoration: BoxDecoration(
                      color: const Color(0xFF232326).withOpacity(0.94),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                      boxShadow: const [
                        BoxShadow(
                            blurRadius: 18,
                            color: Colors.black26,
                            offset: Offset(0, 8)),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon,
                            color: Colors.lightBlueAccent, size: 34),
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

    await autoClose;
    _dialogOpen = false;
  }

  Future<void> _speakAlert(String type) async {
    if (_gmsKey.isEmpty) {
      if (kDebugMode) {
        debugPrint('[SSEAlertOverlay] GMS_KEY not set. Skip TTS.');
      }
      return;
    }

    // 메시지 맵핑
    final text = switch (type) {
      'FRONT_ALERT' => '경고. 전방을 주시하세요.',
      'OXYGEN_ALERT' => '경고. 졸음을 조심하세요.',
      'DISTRACTION_ALERT' => '주의. 졸음 운전이 감지되었습니다.',
      _ => null,
    };
    if (text == null || text.trim().isEmpty) return;

    // 디듑: 같은 타입은 지정 ms 내 재낭독 금지
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastSpeakAt[type] ?? 0;
    if (now - last < widget.speechDedupMs) {
      if (kDebugMode) debugPrint('[SSEAlertOverlay] speech dedup: $type');
      return;
    }
    _lastSpeakAt[type] = now;

    try {
      // 혹시 이미 재생 중이면 중단
      await _player.stop();

      final body = {
        'model': _ttsModel,
        'input': text,
        'voice': _ttsVoice,
        'response_format': 'mp3',
      };

      final res = await _dio.post<List<int>>(
        _ttsUrl,
        data: jsonEncode(body),
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Authorization': 'Bearer $_gmsKey',
            'Content-Type': 'application/json',
          },
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if (!mounted) return;

      if (res.statusCode == 200 && res.data != null) {
        final bytes = Uint8List.fromList(res.data!);
        await _player.play(BytesSource(bytes));
      } else {
        if (kDebugMode) {
          debugPrint(
              '[SSEAlertOverlay] TTS bad status: ${res.statusCode}, len=${res.data?.length ?? 0}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SSEAlertOverlay] TTS error: $e');
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
