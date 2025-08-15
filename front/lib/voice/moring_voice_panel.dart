// lib/voice/moring_voice_panel.dart
// Whisper 기본 + (품질 낮으면) Clova 폴백 하이브리드 STT
// - .env: GMS_KEY, CLOVA_CLIENT_ID, CLOVA_CLIENT_SECRET
// - Whisper(OpenAI) & TTS: GMS 프록시 경유
// - LLM: POST /api/v1/AI/ask (result 또는 string)

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

// 프로젝트에 있으면 사용(없어도 동작하도록 try)
import 'package:moring/providers/api_client.dart' show noAuthDioProvider;

////////////////////////////////////////////////////////////////////////////////
// .env 키
////////////////////////////////////////////////////////////////////////////////
String get _gmsKey => dotenv.maybeGet('GMS_KEY') ?? '';
String get _clovaClientId => dotenv.maybeGet('CLOVA_CLIENT_ID') ?? '';
String get _clovaClientSecret => dotenv.maybeGet('CLOVA_CLIENT_SECRET') ?? '';

////////////////////////////////////////////////////////////////////////////////
// 엔드포인트 상수
////////////////////////////////////////////////////////////////////////////////

// OpenAI(GMS 프록시) 베이스
const _gmsOpenAIBase = 'https://gms.ssafy.io/gmsapi/api.openai.com';

// Whisper
const _whisperUrl = '$_gmsOpenAIBase/v1/audio/transcriptions';
const _whisperModel = 'whisper-1';
const _whisperLanguage = 'ko';

// TTS
const _ttsUrl = '$_gmsOpenAIBase/v1/audio/speech';
const _ttsModel = 'gpt-4o-mini-tts';
const _ttsVoice = 'nova';

// Clova STT
const _clovaUrl = 'https://naveropenapi.apigw.ntruss.com/recog/v1/stt';

// (선택) 내부 LLM API
const _llmPath = '/api/v1/AI/ask';

////////////////////////////////////////////////////////////////////////////////
// VAD/타이밍
////////////////////////////////////////////////////////////////////////////////
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
// STT 결과 모델
////////////////////////////////////////////////////////////////////////////////
class STTResult {
  final String text;
  final double confidence; // 0.0 ~ 1.0
  final String engine;     // 'whisper' | 'clova'
  final Map<String, dynamic>? raw;

  STTResult(this.text, this.confidence, this.engine, {this.raw});
}

////////////////////////////////////////////////////////////////////////////////
// 🔊 하이브리드 음성 비서 패널
////////////////////////////////////////////////////////////////////////////////
class VoiceAssistantPanel extends ConsumerStatefulWidget {
  final bool showDebugPanel; // true면 작은 디버그 카드 출력
  final bool autoStart;      // 자동 루프 시작
  final bool requireWakeWord; // 웨이크워드 필수 여부(모링아)

  const VoiceAssistantPanel({
    super.key,
    this.showDebugPanel = false,
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

  final _wakeWords = const [
    '모링아','모링','머링아','머링','오링아','오링','로링아','로링','보링아','보링',
    '모링가','머리가','머리 감아','오징어','모르냐','브링어','우리가','어링아',
    '오리가','모닝아','모닝','머닝아','머닝','오닝아','오닝','로닝아','로닝','보닝아','보닝',
    '얼른와','머리나','머리냐','무료 영화','뭐래냐','머래냐','머라냐','모리나',
  ];
  final _llmExitWords = const ['모링 종료','모링종료','대화 끝','그만','종료','끝'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isLlmActive = !widget.requireWakeWord;

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
    if (!_looping ||
        !_shouldRun() ||
        _state == VoiceState.processing ||
        _state == VoiceState.listening) {
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
      _ampSub =
          _recorder.onAmplitudeChanged(const Duration(milliseconds: _ampWindowMs)).listen((amp) {
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
        final noSpeechTimeoutHit =
            _isLlmActive && !_speechActive && elapsed >= _noSpeechTimeoutLlmMs;

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

      // 1) Whisper 먼저
      final whisperRes = await _callWhisperStt(f);

      // 2) Whisper 품질이 낮으면 Clova 폴백(키가 있을 때만)
      STTResult finalRes = whisperRes;
      if (_shouldFallbackToClova(whisperRes)) {
        final clovaText = await _callClovaStt(f);
        if (clovaText.isNotEmpty) {
          final clovaConf = _estimateKoreanConfidence(clovaText);
          // 두 후보 비교: 더 긴 한글 비율 + 더 높은 conf 선호
          if (clovaConf >= whisperRes.confidence ||
              _koreanRatio(clovaText) > _koreanRatio(whisperRes.text)) {
            finalRes = STTResult(clovaText, clovaConf, 'clova');
          }
        }
      }

      _lastHeard = finalRes.text.trim();

      if (_lastHeard.isEmpty) {
        _handleEmptyTurn();
        return;
      }

      _emptyTurns = 0;

      if (! _isLlmActive) {
        await _checkForWakeWord(_lastHeard);
      } else {
        await _handleLlmConversation(_lastHeard);
      }

      if (mounted && _state != VoiceState.speaking) {
        _setState(VoiceState.idle);
        await _cooldown();
        _processNextTurn();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Voice] 처리 오류: $e');
      _setStatus('처리 오류');
      if (mounted) {
        _setState(VoiceState.idle);
        await _cooldown();
        _processNextTurn();
      }
    }
  }

  // Whisper → STT
  Future<STTResult> _callWhisperStt(File wav) async {
    if (_gmsKey.isEmpty) {
      if (kDebugMode) debugPrint('[STT] GMS_KEY 미설정(Whisper 호출 불가)');
      return STTResult('', 0.0, 'whisper');
    }
    try {
      final form = FormData.fromMap({
        'model': _whisperModel,
        'file': await MultipartFile.fromFile(
          wav.path,
          filename: 'audio.wav',
          contentType: DioMediaType('audio', 'wav'),
        ),
        'language': _whisperLanguage,
        // verbose_json으로 받아 품질 판단 지표 사용
        'response_format': 'verbose_json',
        // 한국어 구두어 보정 프롬프트(선택)
        'prompt': '한국어 일상 대화. 자동차 내비게이션 맥락. 구어체를 자연스러운 띄어쓰기로.',
        'temperature': '0',
      });

      final res = await _plainDio.post(
        _whisperUrl,
        data: form,
        options: Options(
          headers: {'Authorization': 'Bearer $_gmsKey'},
          responseType: ResponseType.json,
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if (res.statusCode == 200 && res.data is Map) {
        final map = res.data as Map<String, dynamic>;
        final text = (map['text'] as String? ?? '').trim();
        final conf = _estimateWhisperConfidence(map, text);
        if (kDebugMode) {
          debugPrint('[Whisper] text="$text" conf=${conf.toStringAsFixed(2)}');
        }
        return STTResult(text, conf, 'whisper', raw: map);
      }

      if (kDebugMode) {
        debugPrint('[Whisper] 실패 status=${res.statusCode} data=${res.data}');
      }
      return STTResult('', 0.0, 'whisper');
    } catch (e) {
      if (kDebugMode) debugPrint('[Whisper] 예외: $e');
      return STTResult('', 0.0, 'whisper');
    }
  }

  // Whisper 품질 판단(휴리스틱)
  double _estimateWhisperConfidence(Map<String, dynamic> verboseJson, String text) {
    if (text.trim().isEmpty) return 0.0;

    // 기본 점수: 길이/한글비율
    double score = 0.4;
    final len = text.runes.length;
    if (len >= 6) score += 0.1;
    if (len >= 12) score += 0.1;
    score += (_koreanRatio(text) * 0.2); // 한글 비율 가점

    // verbose_json 지표
    final segments = (verboseJson['segments'] as List?)?.cast<Map<String, dynamic>>();
    if (segments != null && segments.isNotEmpty) {
      // avg_logprob 평균 → [-5, 0] 대략 분포 가정 -> [0,1]로 매핑
      double sumProb = 0;
      int c = 0;
      for (final s in segments) {
        final lp = (s['avg_logprob'] as num?)?.toDouble();
        if (lp != null) {
          // -1.5 ~ -0.1 범위를 0~1로 압축
          final mapped = ((lp + 1.5) / 1.4).clamp(0.0, 1.0);
          sumProb += mapped;
          c++;
        }
      }
      if (c > 0) {
        score = max(score, sumProb / c); // 보수적으로 더 높은 쪽 채택
      }
      // 문자 길이로 가볍게 보정
      if (len <= 3) score = min(score, 0.35);
    }

    // 과도한 압축비는 환각/인코딩 이슈 가능
    final comp = (verboseJson['compression_ratio'] as num?)?.toDouble();
    if (comp != null && comp > 2.4) {
      score = min(score, 0.45);
    }

    return score.clamp(0.0, 1.0);
  }

  // 한글 비율 추정
  double _koreanRatio(String s) {
    if (s.isEmpty) return 0.0;
    final total = s.runes.length;
    final korean = RegExp(r'[가-힣]').allMatches(s).fold<int>(0, (p, m) => p + (m.group(0)?.runes.length ?? 0));
    return korean / total;
  }

  // Clova STT (텍스트만 반환)
  Future<String> _callClovaStt(File wavFile) async {
    if (_clovaClientId.isEmpty || _clovaClientSecret.isEmpty) {
      if (kDebugMode) debugPrint('[Clova] 키 미설정 → 폴백 불가');
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
            return (parsed['text'] as String).trim();
          }
        } catch (_) {}
        return (res.data is String && (res.data as String).isNotEmpty)
            ? (res.data as String).trim()
            : '';
      }
      return '';
    } catch (e) {
      if (kDebugMode) debugPrint('[Clova] 예외: $e');
      return '';
    }
  }

  // Clova 텍스트의 대략적 신뢰도(길이 + 한글비율)
  double _estimateKoreanConfidence(String text) {
    if (text.trim().isEmpty) return 0.0;
    double score = 0.5;
    final len = text.runes.length;
    if (len >= 6) score += 0.1;
    if (len >= 12) score += 0.1;
    score += _koreanRatio(text) * 0.2;
    return score.clamp(0.0, 1.0);
  }

  // Whisper 결과가 나빠 보이면 Clova로 폴백 시도
  bool _shouldFallbackToClova(STTResult whisper) {
    if (_clovaClientId.isEmpty || _clovaClientSecret.isEmpty) return false;

    final text = whisper.text.trim();
    if (text.isEmpty) return true;

    // 휴리스틱 조건들
    final confLow = whisper.confidence < 0.58;
    final shortText = text.runes.length <= 2;
    final lowKorean = _koreanRatio(text) < 0.35;
    final hasWeird = RegExp(r'[A-Za-z]{3,}').hasMatch(text); // 영어 연속 등장

    return confLow || shortText || (lowKorean && hasWeird);
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
    final afterWake = _extractAfterWakeWord(raw);
    String userSaid;

    if (afterWake != null) {
      _isLlmActive = true;
      _disarmIdle();
      userSaid = afterWake.trim();

      if (kDebugMode) {
        debugPrint('[Voice] heard(wake): "$raw" -> use("$userSaid")');
      }

      if (userSaid.isEmpty) {
        await _speakOpenAiTts('네, 말씀하세요.');
        return;
      }
    } else {
      userSaid = raw;
      if (kDebugMode) {
        debugPrint('[Voice] heard: "$userSaid"');
      }
    }

    // 2) 종료/중단 명령 처리
    if (_llmExitWords.any((w) => raw.contains(w))) {
      _isLlmActive = false;
      _disarmIdle();
      await _speakOpenAiTts('대화를 종료합니다.');
      if (kDebugMode) debugPrint('[Voice] exit requested.');
      return;
    }

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
      if (kDebugMode) {
        debugPrint(
            '[Voice] TTS speak: "${_lastReply.substring(0, _lastReply.length.clamp(0, 80))}..."');
      }
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
    final start =
    _history.length > _maxTurnsMemory ? _history.length - _maxTurnsMemory : 0;
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

  Future<String> _callLlm(String prompt) async {
    try {
      Dio apiClient;
      try {
        apiClient = ref.read(noAuthDioProvider);
      } catch (_) {
        apiClient = _plainDio..options.baseUrl = '';
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

      // 백엔드가 문자열 본문만 받을 때 대비
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
