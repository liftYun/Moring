// lib/screens/navigation/nav_with_voice.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

// 프로젝트 내 기존 Provider 들 (그대로 사용)
import 'package:moring/providers/api_client.dart';
import 'package:moring/providers/current_car_provider.dart';
import 'package:moring/providers/token_repository.dart';
import 'package:moring/providers/api_client.dart' show noAuthDioProvider;

////////////////////////////////////////////////////////////////////////////////
//                🔊 음성 비서 패널 (STT: Clova / TTS: OpenAI)                //
////////////////////////////////////////////////////////////////////////////////

/// ===== OpenAI(GMS 프록시) TTS 설정 =====
const _gmsKey = 'S13P11E101-1b3cd263-2a3e-4c99-9fa5-8dd56eb86f62';
const _ttsUrl = 'https://gms.ssafy.io/gmsapi/api.openai.com/v1/audio/speech';
const _ttsModel = 'gpt-4o-mini-tts';
const _ttsVoice = 'nova';

/// ===== Clova STT 설정 =====
const _clovaUrl = 'https://naveropenapi.apigw.ntruss.com/recog/v1/stt';
const _clovaClientId = 'vrzfsc9dtl';
const _clovaClientSecret = 'kRKt1yxbapvSObs8RfcaTzcSvHRYUqViWfehaqzW';

/// ===== 백엔드 LLM 엔드포인트 =====
const _llmPath = '/api/v1/AI/ask';

/// ===== 타이밍/감도(VAD) (안정 프로필) =====
const Duration _defaultTurnMax = Duration(seconds: 30);
const int _silenceTimeoutMs = 1200;
const int _minListenMs = 700;
const double _vadDb = -45;
const int _ampWindowMs = 30;
const int _llmMaxListenMs = 30000;
const int _warmupMs = 220;
const int _cooldownMs = 120;
const int _minConsecLoud = 2;
const int _minVoicedMs = 120;
const int _minFileBytes = 8000;
const int _maxTurnsMemory = 6;

/// Idle 타이머(LLM)
const Duration _llmIdle = Duration(seconds: 7);
const Duration _llmGraceAfterWake = Duration(seconds: 5);

/// 무발화 자동 종료
const int _noSpeechTimeoutLlmMs = 3500;
const int _emptyTurnsToExit = 2;

enum VoiceState { idle, listening, processing, speaking }

class VoiceAssistantPanel extends ConsumerStatefulWidget {
  final bool showDebugPanel;
  final bool autoStart;
  final bool requireWakeWord;

  const VoiceAssistantPanel({
    super.key,
    this.showDebugPanel = true,
    this.autoStart = true,
    this.requireWakeWord = true,
  });

  @override
  ConsumerState<VoiceAssistantPanel> createState() => _VoiceAssistantPanelState();
}

class _VoiceAssistantPanelState extends ConsumerState<VoiceAssistantPanel>
    with WidgetsBindingObserver {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final _plainDio = Dio();

  VoiceState _state = VoiceState.idle;
  bool _looping = false;
  bool _isLlmActive = false;

  bool _pageVisible = false;
  bool _appResumed = true;

  StreamSubscription<Amplitude>? _ampSub;
  int _recordStartMs = 0;
  int _lastLoudMs = 0;
  int _consecLoud = 0;
  int _voicedMs = 0;
  bool _speechActive = false;

  Timer? _llmIdleTimer;
  int _idleGen = 0;
  bool _didBumpThisTurn = false;

  int _emptyTurns = 0;

  String _status = '대기';
  String _lastHeard = '';
  String _lastReply = '';

  final List<Map<String, String>> _history = [];
  final List<String> _logs = [];

  final _wakeWords = [
    '모링아','모링','머링아','머링','오링아','오링','로링아','로링','보링아','보링',
    '모링가','머리가','머리 감아','오징어','모르냐','브링어','우리가','어링아',
    '오리가','모닝아','모닝','머닝아','머닝','오닝아','오닝','로닝아','로닝','보닝아','보닝',
    '얼른와','머리나','머리냐','무료 영화','뭐래냐','머래냐','머라냐','모리나',
  ];
  final _llmExitWords = ['모링 종료','모링종료','대화 끝','그만','종료','끝'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isLlmActive = !widget.requireWakeWord;

    // Android 전용 오디오 컨텍스트(에코/노이즈 줄이기)
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

    // TTS 상태 변화
    _player.onPlayerStateChanged.listen((event) {
      if (_state != VoiceState.speaking) return;

      if (event == PlayerState.completed) {
        _log('TTS 재생 완료. 다음 턴으로.');
        _setState(VoiceState.idle);
        if (_isLlmActive) _armIdle(_llmIdle);
        _processNextTurn();
      } else if (event == PlayerState.stopped) {
        _log('TTS 중단됨. 다음 턴으로.');
        _setState(VoiceState.idle);
        _processNextTurn();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageVisible = ModalRoute.of(context)?.isCurrent ?? true;
      if (widget.autoStart && _shouldRun()) _startLoop();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pageVisible = ModalRoute.of(context)?.isCurrent ?? true;
    if (_looping && !_shouldRun()) _stopLoop();
    if (!_looping && widget.autoStart && _shouldRun()) _startLoop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = (state == AppLifecycleState.resumed);
    if (!_appResumed) {
      _log('APP → background, stop loop');
      _stopLoop();
    } else {
      _log('APP → resumed');
      if (widget.autoStart && _shouldRun()) _startLoop();
    }
  }

  bool _shouldRun() => _pageVisible && _appResumed;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLoop();
    _recorder.dispose();
    _player.dispose();
    _ampSub?.cancel();
    _disarmIdle();
    super.dispose();
  }

  Future<void> _startLoop() async {
    if (_looping) return;
    _looping = true;
    _log('LOOP ▶ start');
    _processNextTurn();
  }

  void _stopLoop() {
    if (_looping) {
      _log('LOOP ■ stop');
      _looping = false;
      _recorder.stop();
      _player.stop();
      _setState(VoiceState.idle);
      _ampSub?.cancel();
      _disarmIdle();
      if (mounted) setState(() {});
    }
  }

  void _setState(VoiceState newState) {
    if (_state == newState) return;
    _state = newState;
    if (mounted) setState(() {});
  }

  Future<void> _cooldown() async =>
      Future.delayed(const Duration(milliseconds: _cooldownMs));

  void _processNextTurn() {
    if (!_looping ||
        !_shouldRun() ||
        _state == VoiceState.processing ||
        _state == VoiceState.listening) {
      _log('Next turn skipped. loop=$_looping, run=${_shouldRun()}, state=$_state');
      return;
    }
    _setStatus(_isLlmActive ? '대화 대기 중…' : '녹음 준비…');
    _startListening(
        maxMs: _isLlmActive ? _llmMaxListenMs : _defaultTurnMax.inMilliseconds);
  }

  Future<void> _startListening({required int maxMs}) async {
    if (!mounted || _state == VoiceState.listening) return;

    try {
      final ok = await _recorder.hasPermission();
      if (!ok) {
        _setStatus('마이크 권한 필요');
        _log('권한없음: RECORD_AUDIO');
        _setState(VoiceState.idle);
        await _cooldown();
        _processNextTurn();
        return;
      }

      if (_state == VoiceState.speaking) {
        _log('BARGE-IN: 녹음 시작으로 TTS 중단');
        await _player.stop();
      }

      _setState(VoiceState.listening);
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/moring_turn.wav';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );

      _recordStartMs = DateTime.now().millisecondsSinceEpoch;
      _lastLoudMs = _recordStartMs;
      _consecLoud = 0;
      _voicedMs = 0;
      _speechActive = false;
      _didBumpThisTurn = false;

      _setStatus(_isLlmActive ? '대화 녹음 중…' : '녹음 중…');
      _log('REC ▶ $path');

      await Future.delayed(const Duration(milliseconds: _warmupMs));

      _ampSub?.cancel();
      _ampSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: _ampWindowMs))
          .listen((amp) {
        if (!mounted) return;

        // TTS 중 사용자 발화(Barge-in) → 중단
        if (_state == VoiceState.speaking && amp.current > _vadDb) {
          _log('BARGE-IN 감지! TTS 중단.');
          _ampSub?.cancel();
          _player.stop();
          return;
        }

        final now = DateTime.now().millisecondsSinceEpoch;
        final cur = amp.current;
        final loudFrame = cur.isFinite && cur > _vadDb;

        if (loudFrame) {
          _consecLoud++;
          _lastLoudMs = now;

          if (_consecLoud >= _minConsecLoud) {
            final wasInactive = !_speechActive;
            _speechActive = true;
            _voicedMs += _ampWindowMs;

            if (_isLlmActive && wasInactive && !_didBumpThisTurn) {
              _armIdle(_llmGraceAfterWake);
              _didBumpThisTurn = true;
            }
          }
        } else {
          _consecLoud = 0;
        }
      });

      while (mounted && _state == VoiceState.listening) {
        await Future.delayed(const Duration(milliseconds: 100));
        final now = DateTime.now().millisecondsSinceEpoch;
        final elapsed = now - _recordStartMs;
        final sinceLoud = now - _lastLoudMs;

        final minOk = elapsed >= _minListenMs;
        final silentAfterSpeech = _speechActive && sinceLoud >= _silenceTimeoutMs;
        final overMax = elapsed >= maxMs;
        final noSpeechTimeoutHit =
            _isLlmActive && !_speechActive && elapsed >= _noSpeechTimeoutLlmMs;

        if ((minOk && silentAfterSpeech) || noSpeechTimeoutHit || overMax) {
          break;
        }
      }

      if (mounted && _state == VoiceState.listening) {
        await _stopAndProcess(filePath: path);
      }
    } catch (e, stacktrace) {
      _setStatus('녹음 시작 오류');
      _log('녹음 시작 오류: $e\n$stacktrace');
      if (mounted) {
        _setState(VoiceState.idle);
        await _cooldown();
        _processNextTurn();
      }
    }
  }

  Future<void> _stopAndProcess({required String? filePath}) async {
    if (!mounted || _state != VoiceState.listening) return;

    await _recorder.stop();
    _ampSub?.cancel();
    _setState(VoiceState.processing);

    _log('REC ■ stop (speechActive=$_speechActive, voicedMs=$_voicedMs ms)');

    final wasSpeech = _speechActive && _voicedMs >= _minVoicedMs;

    if (!wasSpeech || filePath == null) {
      _log('무음/짧은 발화 → STT SKIP');
      _handleEmptyTurn();
      return;
    }

    try {
      final f = File(filePath);
      final size = await f.length();
      if (size < _minFileBytes) {
        _log('파일 너무 짧음($size bytes) → STT SKIP');
        _handleEmptyTurn();
        return;
      }

      _setStatus('음성 인식 중…');
      final heard = await _callClovaStt(f);
      _lastHeard = heard.trim();

      if (_lastHeard.isEmpty || _lastHeard.startsWith('[STT')) {
        _log('STT 결과 없음 또는 오류 → 빈 턴으로 처리');
        _handleEmptyTurn();
        return;
      }

      _emptyTurns = 0;
      _log('STT ← "$_lastHeard"');

      if (!_isLlmActive) {
        await _checkForWakeWord(_lastHeard);
      } else {
        await _handleLlmConversation(_lastHeard);
      }

      if (mounted && _state != VoiceState.speaking) {
        _setState(VoiceState.idle);
        await _cooldown();
        _processNextTurn();
      }
    } catch (e, stacktrace) {
      _setStatus('처리 오류');
      _log('처리 오류: $e\n$stacktrace');
      if (mounted) {
        _setState(VoiceState.idle);
        await _cooldown();
        _processNextTurn();
      }
    }
  }

  Future<void> _handleEmptyTurn() async {
    if (!mounted) return;
    if (_isLlmActive) {
      _emptyTurns++;
      if (_emptyTurns >= _emptyTurnsToExit) {
        _isLlmActive = false;
        _disarmIdle();
        _emptyTurns = 0;
        await _speakOpenAiTts('대화가 없어 종료할게요.');
      } else {
        _armIdle(_llmGraceAfterWake);
        _setState(VoiceState.idle);
        await _cooldown();
        _processNextTurn();
      }
    } else {
      _setState(VoiceState.idle);
      await _cooldown();
      _processNextTurn();
    }
  }

  Future<void> _checkForWakeWord(String heardText) async {
    final userText = _extractAfterWakeWord(heardText);
    if (userText != null) {
      _log('웨이크워드 감지 → LLM 활성화');
      _isLlmActive = true;
      _disarmIdle();

      if (userText.trim().isEmpty) {
        await _speakOpenAiTts('네, 말씀하세요.');
        return;
      }
      await _handleLlmConversation(userText.trim());
    }
  }

  Future<void> _handleLlmConversation(String heardText) async {
    final resetText = _extractAfterWakeWord(heardText);
    if (resetText != null && resetText.isNotEmpty) {
      _log('BARGE-IN: 대화 중 웨이크워드 재감지 → 턴 리셋');
      _disarmIdle();
      await _speakOpenAiTts('네, 다시 말씀해 주세요.');
      return;
    }

    if (_llmExitWords.any((w) => heardText.contains(w))) {
      _log('LLM 종료 명령어 감지 → 비활성화');
      _isLlmActive = false;
      _disarmIdle();
      await _speakOpenAiTts('대화를 종료합니다.');
      return;
    }

    final userSaid = heardText.trim();
    if (userSaid.isEmpty) {
      _log('침묵 → 다음 턴');
      return;
    }

    _disarmIdle();
    _setStatus('LLM 요청 중…');

    final prompt = _buildConversationalQuestion(userSaid);
    final answer = await _callLlm(prompt);
    _lastReply = answer.trim();

    _pushHistory('user', userSaid);
    if (_lastReply.isNotEmpty) _pushHistory('assistant', _lastReply);

    if (_lastReply.isNotEmpty) {
      await _speakOpenAiTts(_lastReply);
    } else {
      _setState(VoiceState.idle);
      await _cooldown();
      _processNextTurn();
    }
  }

  void _armIdle([Duration? dur]) {
    if (!_isLlmActive) return;
    final d = dur ?? _llmIdle;
    _idleGen++;
    final myGen = _idleGen;

    _llmIdleTimer?.cancel();
    _llmIdleTimer = Timer(d, () async {
      if (!mounted || myGen != _idleGen) return;
      _log('LLM 대기 시간 초과 → 비활성화');
      if (_state == VoiceState.speaking) {
        await _player.stop();
      }
      _isLlmActive = false;
      await _speakOpenAiTts('응답이 없어 대화를 종료할게요.');
    });
    _log('LLM idle 타이머 재설정: ${d.inMilliseconds}ms (gen=$myGen)');
  }

  void _disarmIdle() {
    _idleGen++;
    _llmIdleTimer?.cancel();
    _llmIdleTimer = null;
    _log('LLM idle 타이머 취소 (gen=$_idleGen)');
  }

  String? _extractAfterWakeWord(String text) {
    if (text.isEmpty) return null;
    final noSpace = text.replaceAll(RegExp(r'\s+'), '');
    for (final w in _wakeWords) {
      if (noSpace.startsWith(w)) {
        final originalIndex = text.toLowerCase().indexOf(w);
        if (originalIndex != -1) {
          return text.substring(originalIndex + w.length).trim();
        }
      }
    }
    return null;
  }

  String _buildConversationalQuestion(String userText) {
    if (_history.isEmpty) return userText;
    final buf = StringBuffer();
    buf.writeln('다음은 지금까지의 대화 맥락입니다:');
    final start = _history.length > _maxTurnsMemory
        ? _history.length - _maxTurnsMemory
        : 0;
    for (int i = start; i < _history.length; i++) {
      final h = _history[i];
      if (h['role'] == 'user') {
        buf.writeln('사용자: ${h['content']}');
      } else {
        buf.writeln('모링: ${h['content']}');
      }
    }
    buf.writeln('\n사용자: $userText');
    buf.writeln('모링:');
    return buf.toString();
  }

  void _pushHistory(String role, String content) {
    _history.add({'role': role, 'content': content});
    if (_history.length > _maxTurnsMemory * 2) {
      _history.removeRange(0, _history.length - _maxTurnsMemory * 2);
    }
  }

  Future<String> _callClovaStt(File wavFile) async {
    if (_clovaClientId.isEmpty || _clovaClientSecret.isEmpty) {
      return '[STT 오류: 클로바 API 키 필요]';
    }
    try {
      final uri = Uri.parse(_clovaUrl).replace(queryParameters: {
        'lang': 'Kor', 'completion': 'sync',
      });
      final bytes = await wavFile.readAsBytes();
      final res = await _plainDio.postUri(
        uri, data: bytes,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'X-NCP-APIGW-API-KEY-ID': _clovaClientId,
            'X-NCP-APIGW-API-KEY': _clovaClientSecret,
            'Content-Type': 'application/octet-stream',
          },
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      _log('STT status=${res.statusCode}, body=${res.data}');
      if (res.statusCode == 200) {
        try {
          final parsed = json.decode(res.data);
          if (parsed is Map && parsed['text'] is String) {
            return parsed['text'] as String;
          }
        } catch (_) {}
        return (res.data is String && (res.data as String).isNotEmpty)
            ? (res.data as String)
            : '';
      }
      return '';
    } catch (e) {
      return '[STT 예외: $e]';
    }
  }

  Future<String> _callLlm(String prompt) async {
    try {
      Dio apiClient;
      try {
        apiClient = ref.read(noAuthDioProvider);
      } catch (_) {
        apiClient = _plainDio;
      }
      Response res = await apiClient.post(
        _llmPath, data: {'question': prompt},
        options: Options(
          headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
          responseType: ResponseType.json,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      String? ans = _extractLlmResult(res);
      if (ans != null) return ans;

      res = await apiClient.post(
        _llmPath, data: prompt,
        options: Options(
          headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
          responseType: ResponseType.json,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      ans = _extractLlmResult(res);
      return ans ?? '[LLM 응답 파싱 실패]';
    } catch (e) {
      return '[LLM 호출 실패: $e]';
    }
  }

  String? _extractLlmResult(Response res) {
    _log('LLM status=${res.statusCode}, type=${res.data.runtimeType}, data=${res.data}');
    if (res.statusCode == 200) {
      final data = res.data;
      if (data is Map && data.containsKey('result') && data['result'] is String) {
        return (data['result'] as String).trim();
      }
      if (data is String) return data.trim();
    }
    return null;
  }

  Future<void> _speakOpenAiTts(String text) async {
    if (text.trim().isEmpty) return;
    if (!mounted) return;

    _setState(VoiceState.speaking);
    _setStatus('음성 답변 중…');

    try {
      final body = {
        'model': _ttsModel,
        'input': text,
        'voice': _ttsVoice,
        'response_format': 'mp3',
      };

      final res = await _plainDio.post(
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

      if (!mounted) return;

      if (res.statusCode == 200 && res.data != null) {
        final bytes = Uint8List.fromList(res.data as List<int>);
        await _player.play(BytesSource(bytes));
      } else {
        _log('TTS 실패: ${res.statusCode}, ${res.data}');
        _setState(VoiceState.idle);
        _processNextTurn();
      }
    } catch (e) {
      _log('TTS 오류: $e');
      if (mounted) {
        _setState(VoiceState.idle);
        _processNextTurn();
      }
    }
  }

  void _setStatus(String s) {
    if (mounted) setState(() => _status = s);
  }

  void _log(String m) {
    if (kDebugMode) debugPrint('[VOICE] $m');
    if (mounted && widget.showDebugPanel) {
      setState(() {
        _logs.add(m);
        if (_logs.length > 160) _logs.removeRange(0, _logs.length - 160);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _pageVisible = ModalRoute.of(context)?.isCurrent ?? true;
    if (!widget.showDebugPanel) return const SizedBox.shrink();

    IconData iconData;
    Color iconColor;

    switch (_state) {
      case VoiceState.listening:
        iconData = Icons.mic;
        iconColor = Colors.redAccent;
        break;
      case VoiceState.speaking:
        iconData = Icons.volume_up;
        iconColor = Colors.lightBlueAccent;
        break;
      case VoiceState.processing:
        iconData = Icons.sync;
        iconColor = Colors.orangeAccent;
        break;
      default:
        iconData = Icons.mic_none;
        iconColor = Colors.white70;
        break;
    }

    if (_isLlmActive) {
      iconData = _state == VoiceState.listening ? Icons.chat : Icons.chat_bubble_outline;
      iconColor = Colors.greenAccent;
    }

    return Card(
      color: const Color(0xFF1D1F22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(iconData, color: iconColor),
                const SizedBox(width: 8),
                Expanded(child: Text('상태: $_status', style: const TextStyle(color: Colors.white))),
                const SizedBox(width: 6),
                Text(
                  _looping ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(
                    color: _looping ? Colors.lightGreenAccent : Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _infoRow('인식', _lastHeard),
            const SizedBox(height: 6),
            _infoRow('응답', _lastReply, highlight: true),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(onPressed: _looping ? null : _startLoop, child: const Text('자동 시작')),
                OutlinedButton(onPressed: _looping ? _stopLoop : null, child: const Text('자동 중지')),
                OutlinedButton(
                  onPressed: () async {
                    final ans = await _callLlm('테스트 문장입니다. 대답 가능합니까?');
                    if (mounted) {
                      setState(() {
                        _lastReply = ans;
                        _pushHistory('user', '테스트 문장입니다. 대답 가능합니까?');
                        if (_lastReply.isNotEmpty) _pushHistory('assistant', _lastReply);
                      });
                    }
                  },
                  child: const Text('LLM 테스트'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    await _player.stop();
                    await _speakOpenAiTts('오디오 장치 테스트입니다.');
                  },
                  child: const Text('TTS 테스트'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('로그', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Container(
              height: 180,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF141517),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: ListView.builder(
                reverse: true,
                itemCount: _logs.length,
                itemBuilder: (_, i) => Text(
                  _logs.reversed.toList()[i],
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool highlight = false}) {
    final color = highlight ? Colors.lightBlueAccent : Colors.white;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 36, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
        const SizedBox(width: 8),
        Expanded(child: Text(value.isEmpty ? '—' : value, style: TextStyle(color: color, fontSize: 14))),
      ],
    );
  }
}

////////////////////////////////////////////////////////////////////////////////
//                       🚗 네비 + SSE + 음성 패널 화면                        //
////////////////////////////////////////////////////////////////////////////////

class NavWithVoicePage extends ConsumerStatefulWidget {
  const NavWithVoicePage({Key? key}) : super(key: key);

  @override
  ConsumerState<NavWithVoicePage> createState() => _NavWithVoicePageState();
}

class _NavWithVoicePageState extends ConsumerState<NavWithVoicePage> {
  StreamSubscription<SSEModel>? _sub;
  Timer? _renewTimer;

  bool _connected = false;
  String? _vin;
  String? _connectUrl;
  Map<String, String> _headers = const {};

  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _prepareConnectionInfo();
      _connect();
      _renewTimer = Timer.periodic(const Duration(minutes: 25), (_) => _reconnect());
    });
  }

  Future<void> _prepareConnectionInfo() async {
    final dio = ref.read(authDioProvider);
    final car = ref.read(currentCarProvider);

    _vin = car?.vin;
    if (_vin == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('VIN이 없어 SSE 연결을 시작할 수 없습니다.')),
      );
      return;
    }

    final base = dio.options.baseUrl;
    _connectUrl = '$base/api/v1/notifications/connect/$_vin';

    final repo = ref.read(tokenRepositoryProvider);
    final accessToken = await repo.getAccessToken();

    _headers = {
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Accept-Encoding': 'identity',
    };

    debugPrint('SSE URL: $_connectUrl');
    debugPrint('SSE Headers: $_headers');
  }

  void _connect() {
    if (_connectUrl == null) return;
    _disconnect();

    _sub = SSEClient.subscribeToSSE(
      url: _connectUrl!,
      header: _headers,
      method: SSERequestType.GET,
    ).listen((event) {
      setState(() => _connected = true);
      final dataStr = event.data ?? '';
      if (dataStr.isEmpty) return;
      try {
        final Map<String, dynamic> payload = jsonDecode(dataStr);
        _handleAlert('${payload['type']}');
      } catch (_) {
        _handleRaw(dataStr);
      }
    }, onError: (err) {
      debugPrint('SSE ERROR: $err');
      setState(() => _connected = false);
      Future.delayed(const Duration(seconds: 3), _reconnect);
    }, onDone: () {
      debugPrint('SSE DONE');
      setState(() => _connected = false);
      Future.delayed(const Duration(seconds: 1), _reconnect);
    });
  }

  void _reconnect() {
    _disconnect();
    _prepareConnectionInfo().then((_) => _connect());
  }

  void _disconnect() {
    _sub?.cancel();
    _sub = null;
  }

  void _handleRaw(String msg) {
    if (msg.contains('FRONT_ALERT')) _handleAlert('FRONT_ALERT');
    else if (msg.contains('OXYGEN_ALERT')) _handleAlert('OXYGEN_ALERT');
    else if (msg.contains('DISTRACTION_ALERT')) _handleAlert('DISTRACTION_ALERT');
  }

  Future<void> _handleAlert(String type) async {
    if (!mounted || _dialogOpen) return;

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
      default:
        return;
    }

    _dialogOpen = true;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF232326),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(icon, color: Colors.lightBlueAccent),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
  }

  @override
  void dispose() {
    _renewTimer?.cancel();
    _disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dio = ref.watch(authDioProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_connected ? 'SSE 연결됨' : 'SSE 연결 안 됨'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            tooltip: '연결 상태 확인',
            icon: const Icon(Icons.task_alt),
            onPressed: () async {
              final vin = _vin ?? ref.read(currentCarProvider)?.vin;
              if (vin == null) return;
              try {
                final r = await dio.get('/api/v1/notifications/status/$vin');
                final ok = r.data is Map && (r.data['result'] == true);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('status: ${ok ? "connected" : "disconnected"}')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('status error: $e')),
                );
              }
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFF0F0F10),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  _connected ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                  color: _connected ? Colors.lightGreenAccent : Colors.redAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _connectUrl ?? '(URL 준비 중)',
                    style: const TextStyle(color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _reconnect, child: const Text('재연결')),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _handleAlert('FRONT_ALERT'),
                  child: const Text('TEST FRONT_ALERT'),
                ),
                OutlinedButton(
                  onPressed: () => _handleAlert('OXYGEN_ALERT'),
                  child: const Text('TEST OXYGEN_ALERT'),
                ),
                OutlinedButton(
                  onPressed: () => _handleAlert('DISTRACTION_ALERT'),
                  child: const Text('TEST DISTRACTION_ALERT'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // 🎙 내장형 대화형 AI 패널
            const VoiceAssistantPanel(
              showDebugPanel: true,
              autoStart: true,
              requireWakeWord: true,
            ),
          ],
        ),
      ),
    );
  }
}
