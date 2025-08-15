// lib/screens/navigation/sse_with_voice.dart
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
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

// 프로젝트 Provider
import 'package:moring/providers/api_client.dart';
import 'package:moring/providers/api_client.dart' show noAuthDioProvider;
import 'package:moring/providers/current_car_provider.dart';
import 'package:moring/providers/token_repository.dart';

////////////////////////////////////////////////////////////////////////////////
// .env 키 Getter
////////////////////////////////////////////////////////////////////////////////
String get _gmsKey => dotenv.maybeGet('GMS_KEY') ?? '';
String get _clovaClientId => dotenv.maybeGet('CLOVA_CLIENT_ID') ?? '';
String get _clovaClientSecret => dotenv.maybeGet('CLOVA_CLIENT_SECRET') ?? '';

////////////////////////////////////////////////////////////////////////////////
// 공통 상수
////////////////////////////////////////////////////////////////////////////////

/// OpenAI(GMS 프록시) TTS
const _ttsUrl = 'https://gms.ssafy.io/gmsapi/api.openai.com/v1/audio/speech';
const _ttsModel = 'gpt-4o-mini-tts';
const _ttsVoice = 'nova';

/// Clova STT
const _clovaUrl = 'https://naveropenapi.apigw.ntruss.com/recog/v1/stt';

/// 백엔드 LLM 엔드포인트
const _llmPath = '/api/v1/AI/ask';

/// VAD/타이밍
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

/// LLM idle
const Duration _llmIdle = Duration(seconds: 7);
const Duration _llmGraceAfterWake = Duration(seconds: 5);

/// 무발화 자동 종료
const int _noSpeechTimeoutLlmMs = 3500;
const int _emptyTurnsToExit = 2;

enum VoiceState { idle, listening, processing, speaking }

////////////////////////////////////////////////////////////////////////////////
// 🔊 음성 비서 패널 (Clova STT + GMS TTS) — 화면엔 안 보이도록 구성 가능
////////////////////////////////////////////////////////////////////////////////

class VoiceAssistantPanel extends ConsumerStatefulWidget {
  final bool showDebugPanel; // false면 UI 렌더 안 함(로직만 동작)
  final bool autoStart;
  final bool requireWakeWord;

  const VoiceAssistantPanel({
    super.key,
    this.showDebugPanel = false, // 기본값: 숨김
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isLlmActive = !widget.requireWakeWord;

    // Android 오디오 포커스
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
      if (event == PlayerState.completed || event == PlayerState.stopped) {
        _setState(VoiceState.idle);
        if (_isLlmActive) _armIdle(_llmIdle);
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
    if (!_appResumed) _stopLoop();
    if (_appResumed && widget.autoStart && _shouldRun()) _startLoop();
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
    _processNextTurn();
  }

  void _stopLoop() {
    if (_looping) {
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
    if (mounted && widget.showDebugPanel) setState(() {});
  }

  Future<void> _cooldown() async =>
      Future.delayed(const Duration(milliseconds: _cooldownMs));

  void _processNextTurn() {
    if (!_looping || !_shouldRun() || _state == VoiceState.processing || _state == VoiceState.listening) {
      return;
    }
    _setStatus(_isLlmActive ? '대화 대기 중…' : '녹음 준비…');
    _startListening(maxMs: _isLlmActive ? _llmMaxListenMs : _defaultTurnMax.inMilliseconds);
  }

  Future<void> _startListening({required int maxMs}) async {
    if (!mounted || _state == VoiceState.listening) return;

    try {
      final ok = await _recorder.hasPermission();
      if (!ok) {
        _setStatus('마이크 권한 필요');
        _setState(VoiceState.idle);
        await _cooldown();
        _processNextTurn();
        return;
      }

      if (_state == VoiceState.speaking) {
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

      await Future.delayed(const Duration(milliseconds: _warmupMs));

      _ampSub?.cancel();
      _ampSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: _ampWindowMs))
          .listen((amp) {
        if (!mounted) return;

        if (_state == VoiceState.speaking && amp.current > _vadDb) {
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
        final noSpeechTimeoutHit = _isLlmActive && !_speechActive && elapsed >= _noSpeechTimeoutLlmMs;

        if ((minOk && silentAfterSpeech) || noSpeechTimeoutHit || overMax) break;
      }

      if (mounted && _state == VoiceState.listening) {
        await _stopAndProcess(filePath: path);
      }
    } catch (_) {
      _setStatus('녹음 시작 오류');
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

    final wasSpeech = _speechActive && _voicedMs >= _minVoicedMs;

    if (!wasSpeech || filePath == null) {
      _handleEmptyTurn();
      return;
    }

    try {
      final f = File(filePath);
      final size = await f.length();
      if (size < _minFileBytes) {
        _handleEmptyTurn();
        return;
      }

      _setStatus('음성 인식 중…');
      final heard = await _callClovaStt(f);
      _lastHeard = heard.trim();

      if (_lastHeard.isEmpty || _lastHeard.startsWith('[STT')) {
        _handleEmptyTurn();
        return;
      }

      _emptyTurns = 0;

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
    } catch (_) {
      _setStatus('처리 오류');
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
    // 1) 원문/웨이크워드 처리
    final raw = heardText.trim();
    final afterWake = _extractAfterWakeWord(raw); // 웨이크워드가 포함되면 나머지 텍스트 반환, 없으면 null
    String userSaid;

    if (afterWake != null) {
      // 웨이크워드가 들어온 턴: 바로 해당 내용으로 이어서 대화
      _isLlmActive = true;       // 웨이크워드가 들렸으니 LLM 모드 온
      _disarmIdle();             // idle 타이머 해제
      userSaid = afterWake.trim();

      if (kDebugMode) {
        debugPrint('[Voice] heard(wake): "$raw" -> use("$userSaid")');
      }

      // 웨이크워드만 말했을 때(내용 없음)
      if (userSaid.isEmpty) {
        await _speakOpenAiTts('네, 말씀하세요.');
        return;
      }
    } else {
      // 웨이크워드 없이 바로 질문
      userSaid = raw;
      if (kDebugMode) {
        debugPrint('[Voice] heard: "$userSaid"');
      }
    }

    // 2) 종료/중단 명령 처리 (원문 기준으로 체크)
    if (['모링 종료','모링종료','대화 끝','그만','종료','끝'].any((w) => raw.contains(w))) {
      _isLlmActive = false;
      _disarmIdle();
      await _speakOpenAiTts('대화를 종료합니다.');
      if (kDebugMode) debugPrint('[Voice] exit requested.');
      return;
    }

    // 3) 빈 문자열 가드
    if (userSaid.isEmpty) {
      if (kDebugMode) debugPrint('[Voice] empty user text after processing.');
      return;
    }

    // 4) LLM 호출
    _disarmIdle();
    _setStatus('LLM 요청 중…');
    if (kDebugMode) debugPrint('[Voice] calling LLM with: "$userSaid"');

    final prompt = _buildConversationalQuestion(userSaid);
    final answer = await _callLlm(prompt);
    _lastReply = answer.trim();

    _pushHistory('user', userSaid);
    if (_lastReply.isNotEmpty) _pushHistory('assistant', _lastReply);

    // 5) 응답 TTS
    if (_lastReply.isNotEmpty) {
      if (kDebugMode) debugPrint('[Voice] TTS speak: "${_lastReply.substring(0, _lastReply.length.clamp(0, 80))}..."');
      await _speakOpenAiTts(_lastReply);
    } else {
      if (kDebugMode) debugPrint('[Voice] empty LLM reply.');
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
      if (_state == VoiceState.speaking) {
        await _player.stop();
      }
      _isLlmActive = false;
      await _speakOpenAiTts('응답이 없어 대화를 종료할게요.');
    });
  }

  void _disarmIdle() {
    _idleGen++;
    _llmIdleTimer?.cancel();
    _llmIdleTimer = null;
  }

  String? _extractAfterWakeWord(String text) {
    if (text.isEmpty) return null;
    final noSpace = text.replaceAll(RegExp(r'\s+'), '');
    // 일부 오타 포함 웨이크워드
    for (final w in const [
      '모링아','모링','머링아','머링','오링아','오링','로링아','로링','보링아','보링',
      '모링가','머리가','머리 감아','오징어','모르냐','브링어','우리가','어링아',
      '오리가','모닝아','모닝','머닝아','머닝','오닝아','오닝','로닝아','로닝','보닝아','보닝',
      '얼른와','머리나','머리냐','무료 영화','뭐래냐','머래냐','머라냐','모리나',
    ]) {
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
    final start = _history.length > _maxTurnsMemory ? _history.length - _maxTurnsMemory : 0;
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
      if (kDebugMode) debugPrint('[STT] CLOVA 키 미설정');
      return '';
    }
    try {
      final uri = Uri.parse(_clovaUrl).replace(queryParameters: {
        'lang': 'Kor',
        'completion': 'sync',
      });
      final bytes = await wavFile.readAsBytes();
      final res = await _plainDio.postUri(
        uri,
        data: bytes,
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
      if (res.statusCode == 200) {
        try {
          final parsed = json.decode(res.data);
          if (parsed is Map && parsed['text'] is String) {
            return parsed['text'] as String;
          }
        } catch (_) {}
        return (res.data is String && (res.data as String).isNotEmpty) ? (res.data as String) : '';
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
        _llmPath,
        data: {'question': prompt},
        options: Options(
          headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
          responseType: ResponseType.json,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      String? ans = _extractLlmResult(res);
      if (ans != null) return ans;

      res = await apiClient.post(
        _llmPath,
        data: prompt,
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
    if (_gmsKey.isEmpty) {
      if (kDebugMode) debugPrint('[TTS] GMS_KEY 미설정');
      return;
    }

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
        _setState(VoiceState.idle);
        _processNextTurn();
      }
    } catch (_) {
      if (mounted) {
        _setState(VoiceState.idle);
        _processNextTurn();
      }
    }
  }

  void _setStatus(String s) {
    if (mounted && widget.showDebugPanel) setState(() => _status = s);
  }

  @override
  Widget build(BuildContext context) {
    // showDebugPanel=false 이면 UI 없음(로직은 동작)
    return const SizedBox.shrink();
  }
}

////////////////////////////////////////////////////////////////////////////////
// 🚗 네비 + SSE + “반투명 자동 닫힘(5초)” 모달 + (보이지 않는) 음성 패널
////////////////////////////////////////////////////////////////////////////////

class NavWithVoicePage extends ConsumerStatefulWidget {
  const NavWithVoicePage({Key? key}) : super(key: key);

  @override
  ConsumerState<NavWithVoicePage> createState() => _NavWithVoicePageState();
}

class _NavWithVoicePageState extends ConsumerState<NavWithVoicePage> {
  StreamSubscription<SSEModel>? _sub;
  Timer? _renewTimer;

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
      if (kDebugMode) debugPrint('[SSE] VIN이 없어 연결을 시작할 수 없습니다.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('VIN이 없어 SSE 연결을 시작할 수 없습니다.')),
      );
      return;
    }

    final base = dio.options.baseUrl;
    _connectUrl = '$base/api/v1/notifications/connect/$_vin';
    if (kDebugMode) debugPrint('[SSE] 연결 URL 준비: $_connectUrl');

    final repo = ref.read(tokenRepositoryProvider);
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

    _sub = SSEClient.subscribeToSSE(
      url: _connectUrl!,
      header: _headers,
      method: SSERequestType.GET,
    ).listen((event) {
      final evt = (event.event ?? '').trim();
      final raw = (event.data ?? '').trim();

      if (kDebugMode) {
        debugPrint('[SSE] 📩 이벤트 수신');
        debugPrint('  • id: ${event.id ?? ''}');
        debugPrint('  • event: $evt');
        debugPrint('  • data(raw): $raw\n');
      }

      // 1) event 이름으로 직접 매칭
      final upperEvt = evt.toUpperCase();
      if (upperEvt == 'FRONT_ALERT' ||
          upperEvt == 'OXYGEN_ALERT' ||
          upperEvt == 'DISTRACTION_ALERT') {
        _handleAlert(upperEvt);
        return;
      }

      // 2) data(JSON) 에 type 있으면 매칭
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
        } catch (_) {
          // JSON 아님 → 3) 원시 문자열 매칭
        }
      }

      // 3) 원시 문자열 매칭(서버가 단문 텍스트만 보낼 때)
      _handleRaw(raw, evt);
    }, onError: (e) {
      if (kDebugMode) debugPrint('[SSE] 연결 오류 발생: $e. 3초 후 재연결 시도.');
      Future.delayed(const Duration(seconds: 3), _reconnect);
    }, onDone: () {
      if (kDebugMode) debugPrint('[SSE] 연결 종료됨. 1초 후 재연결 시도.');
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
    if (kDebugMode) debugPrint('[SSE] ⏏️ 연결 해제됨.');
  }

  void _handleRaw(String msg, String evtName) {
    if (kDebugMode) debugPrint('[Alert] 📝 원시 데이터: $msg');

    // 연결 안내 텍스트/이벤트는 모달 생략
    if (msg.contains('SSE 연결이 성공적으로 설정') ||
        evtName.toLowerCase() == 'connect') {
      if (kDebugMode) debugPrint('[Alert] ℹ️ 연결 성공 안내. 모달 생략.');
      return;
    }

    // 한국어/키워드 매칭
    final s = msg.replaceAll(' ', '');
    if (s.contains('전방') || s.toUpperCase().contains('FRONT_ALERT')) {
      _handleAlert('FRONT_ALERT');
    } else if (s.contains('에어컨') || s.toUpperCase().contains('OXYGEN_ALERT')) {
      _handleAlert('OXYGEN_ALERT');
    } else if (s.contains('졸음') || s.toUpperCase().contains('DISTRACTION_ALERT')) {
      _handleAlert('DISTRACTION_ALERT');
    } else {
      if (kDebugMode) debugPrint('[Alert] 알 수 없는 타입: ${evtName.isEmpty ? '(no event)' : evtName}');
    }
  }

  Future<void> _handleAlert(String type) async {
    if (!mounted || _dialogOpen) {
      if (kDebugMode) {
        debugPrint('[Alert] 모달 표시 불가. mounted=$mounted, _dialogOpen=$_dialogOpen');
      }
      return;
    }

    String title = '알림';
    String message = '';
    IconData icon = Icons.notifications_active;

    switch (type.toUpperCase()) {
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
        if (kDebugMode) debugPrint('[Alert] 매칭되지 않은 타입: $type');
        return;
    }

    _dialogOpen = true;
    if (kDebugMode) debugPrint('[Alert] ✅ 모달 표시 시도: $type');

    // 5초 후 자동 닫힘
    final autoClose = Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _dialogOpen) {
        if (kDebugMode) debugPrint('[Alert] ⏱ 자동 닫힘(5초)');
        Navigator.of(context, rootNavigator: true).pop('auto');
      }
    });

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '닫기', // 접근성 및 어설션 충족
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
                          children: const [
                            Text(
                              '알림',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                            SizedBox(height: 8),
                            // 실제 메시지는 아래에서 별도로 빌드
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
      // builder가 없을 때 message를 못 넣으므로, transitionBuilder로 message 포함 카드 출력
      transitionBuilder: (context, anim1, anim2, child) {
        // child는 위의 pageBuilder 결과 — 여기에 message를 다시 그려주기
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

    await autoClose; // 이미 닫혔으면 noop
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
    // 이 페이지는 "네비 화면 위에서 조용히 동작"하는 게 목표
    return Stack(
      children: const [
        // 지도 등 메인 UI는 상위에서 배치

        // 보이지 않지만 로직은 동작하는 음성 패널
        Positioned.fill(
          child: IgnorePointer(
            ignoring: true, // 터치 막지 않도록
            child: VoiceAssistantPanel(
              showDebugPanel: false, // UI 렌더 X
              autoStart: true,
              requireWakeWord: true,
            ),
          ),
        ),
      ],
    );
  }
}
