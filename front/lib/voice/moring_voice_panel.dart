// lib/voice/moring_voice_panel.dart
// Whisper(상시) + Clova(폴백) + 내부 LLM + OpenAI TTS

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

// 전역 RouteObserver (main.dart에 정의)
import 'package:moring/main.dart' show routeObserver;

// 인증/무인증 클라이언트
import 'package:moring/providers/api_client.dart'
    show authDioProvider, noAuthDioProvider;

// ─────────────────────────────────────────────────────────────────────────────
// .env 키
String get _gmsKey => dotenv.maybeGet('GMS_KEY') ?? '';
String get _clovaClientId => dotenv.maybeGet('CLOVA_CLIENT_ID') ?? '';
String get _clovaClientSecret => dotenv.maybeGet('CLOVA_CLIENT_SECRET') ?? '';

// 엔드포인트
const _gmsOpenAIBase = 'https://gms.ssafy.io/gmsapi/api.openai.com';
const _whisperUrl = '$_gmsOpenAIBase/v1/audio/transcriptions';
const _whisperModel = 'whisper-1';
const _whisperLanguage = 'ko';
const _ttsUrl = '$_gmsOpenAIBase/v1/audio/speech';
const _ttsModel = 'gpt-4o-mini-tts';
const _ttsVoice = 'nova';
const _clovaUrl = 'https://naveropenapi.apigw.ntruss.com/recog/v1/stt';
const _llmPath = '/api/v1/AI/ask';

// VAD/타이밍 (튜닝)
const Duration _defaultTurnMax = Duration(seconds: 20);
const int _silenceTimeoutMs = 900;
const int _minListenMs = 500;
const double _vadDb = -55;
const int _ampWindowMs = 25;

const int _llmMaxListenMs = 25000;
const int _warmupMs = 180;
const int _cooldownMs = 100;
const int _minConsecLoud = 1;
const int _minVoicedMs = 90;
const int _minFileBytes = 8000;

// 대화 유지
const int _maxTurnsMemory = 6;
const Duration _llmIdle = Duration(seconds: 12);
const Duration _llmGraceAfterWake = Duration(seconds: 6);
const int _noSpeechTimeoutLlmMs = 3000;
const int _noSpeechTimeoutWakeMs = 4000;
const int _emptyTurnsToExit = 2;

// TTS 가드
const int _postTtsGuardMs = 800;
const int _needFramesToInterrupt = 6;

enum VoiceState { idle, listening, processing, speaking }

class STTResult {
  final String text;
  final double confidence; // 0~1
  final String engine;     // whisper | clova
  final Map<String, dynamic>? raw;
  STTResult(this.text, this.confidence, this.engine, {this.raw});
}

// ─────────────────────────────────────────────────────────────────────────────
// 위젯
class VoiceAssistantPanel extends ConsumerStatefulWidget {
  final bool showDebugPanel;
  final bool autoStart;
  final bool requireWakeWord;
  final bool showBadge;
  final bool showBadgeOnlyWhenActive;
  final Alignment badgeAlignment;
  final EdgeInsets badgeMargin;
  final double avoidBottomPx;

  const VoiceAssistantPanel({
    super.key,
    this.showDebugPanel = false,
    this.autoStart = true,
    this.requireWakeWord = true,
    this.showBadge = true,
    this.showBadgeOnlyWhenActive = true,
    this.badgeAlignment = Alignment.bottomCenter,
    this.badgeMargin = EdgeInsets.zero,
    this.avoidBottomPx = 104,
  });

  @override
  ConsumerState<VoiceAssistantPanel> createState() => _VoiceAssistantPanelState();
}

class _VoiceAssistantPanelState extends ConsumerState<VoiceAssistantPanel>
    with WidgetsBindingObserver, RouteAware {
  // 싱글톤 오너 가드
  static bool _globalActive = false;
  bool _isOwner = false;

  // 내부 상태
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
  String _lastAssistant = '';

  int _interruptLoudFrames = 0;
  int _speakEndedAtMs = 0;

  int _lastActivityMs = 0;
  bool _nextTurnScheduled = false;

  final List<Map<String, String>> _history = [];
  double _lastAmpDb = double.nan;

  // ⬇️ 중첩 방지용: LLM 파이프라인 락 + 대기열(최신 1건)
  bool _llmBusy = false;
  String? _queuedUserText;

  final List<String> _wakeWords = const [
    '모링아','모링','머링아','머링','오링아','오링','로링아','로링','보링아','보링',
    '모링가','머리가','머리 감아','오징어','모르냐','브링어','우리가','어링아','오리가',
    '모닝아','모닝','머닝아','머닝','오닝아','오닝','로닝아','로닝','보닝아','보닝',
    '얼른와','머리나','머리냐','무료 영화','뭐래냐','머래냐','머라냐','모리나','어린아','어랭아'
    '올리나','우링아'
  ];

  final List<String> _llmExitWords = const [
    '모링 종료','없다','모링종료','대화 끝','그만','종료','끝','없어'
  ];

  final List<String> _sttBlacklistExact = const [
    '자동차 내비게이션 맥락','내비게이션 맥락','자동차 내비게이션',
    '자연스러운 띄어쓰기','대화 맥락','모링:','친구:',
  ];
  final List<RegExp> _sttBlacklistPatterns = [
    RegExp(r'^(자동차\s*)?내비게이션\s*맥락$', caseSensitive: false),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (!_globalActive) {
      _globalActive = true;
      _isOwner = true;
    } else {
      _isOwner = false;
    }

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

    _player.onPlayerStateChanged.listen((event) async {
      if (!_isOwner) return;
      if (_state != VoiceState.speaking) return;
      if (event == PlayerState.completed || event == PlayerState.stopped) {
        _setState(VoiceState.idle);
        _speakEndedAtMs = DateTime.now().millisecondsSinceEpoch;
        _markActivity();
        if (_isLlmActive) _armIdle(_llmIdle);

        // TTS가 끝나면, 대기열에 쌓인 턴을 우선 처리
        final pending = _queuedUserText;
        _queuedUserText = null;
        _llmBusy = false; // 다음 턴 허용
        if (pending != null && pending.trim().isNotEmpty) {
          // 바로 이어서 처리
          unawaited(_handleLlmConversation(pending));
        } else {
          _scheduleNextTurn(_postTtsGuardMs);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markActivity();
      _pageVisible = ModalRoute.of(context)?.isCurrent ?? true;
      if (_isOwner && widget.autoStart && _shouldRun()) _startLoop();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
      _pageVisible = route.isCurrent;
    }

    if (!_isOwner) return;
    if (_looping && !_shouldRun()) _stopLoop();
    if (!_looping && widget.autoStart && _shouldRun()) _startLoop();
  }

  @override
  void dispose() {
    try { routeObserver.unsubscribe(this); } catch (_) {}
    WidgetsBinding.instance.removeObserver(this);
    if (_isOwner) {
      _stopLoop();
      _recorder.dispose();
      _player.dispose();
      _ampSub?.cancel();
      _disarmIdle();
      _globalActive = false;
    }
    super.dispose();
  }

  // RouteAware
  @override
  void didPush() { _pageVisible = true; if (_isOwner && widget.autoStart && _shouldRun()) _startLoop(); }
  @override
  void didPopNext() { _pageVisible = true; if (_isOwner && widget.autoStart && _shouldRun()) _startLoop(); }
  @override
  void didPushNext() { _pageVisible = false; if (_isOwner) _stopLoop(); }
  @override
  void didPop() { _pageVisible = false; if (_isOwner) _stopLoop(); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = (state == AppLifecycleState.resumed);
    if (!_isOwner) return;
    if (!_appResumed) _stopLoop();
    if (_appResumed && widget.autoStart && _shouldRun()) _startLoop();
  }

  bool _shouldRun() => _pageVisible && _appResumed;

  void _markActivity() { _lastActivityMs = DateTime.now().millisecondsSinceEpoch; }

  void _scheduleNextTurn([int delayMs = 0]) {
    if (!_isOwner) return;
    if (_nextTurnScheduled) return;
    _nextTurnScheduled = true;
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      _nextTurnScheduled = false;
      _processNextTurn();
    });
  }

  Future<void> _startLoop() async {
    if (!_isOwner) return;
    if (_looping) return;
    _looping = true;
    _scheduleNextTurn();
  }

  void _stopLoop() {
    if (!_isOwner) return;
    if (_looping) {
      _looping = false;
      _recorder.stop();
      _player.stop();
      _ampSub?.cancel();
      _disarmIdle();
      _setState(VoiceState.idle);
      if (mounted && (widget.showDebugPanel || widget.showBadge)) setState(() {});
    }
  }

  void _setState(VoiceState s) {
    if (_state == s) return;
    _state = s;
    if (mounted && (widget.showDebugPanel || widget.showBadge)) setState(() {});
  }

  void _processNextTurn() {
    if (!_isOwner) return;
    if (!_looping || !_shouldRun()) return;
    if (_state == VoiceState.processing || _state == VoiceState.listening) return;
    if (_llmBusy) return; // ⬅️ LLM 파이프라인 중엔 재녹음 금지

    _setStatus(_isLlmActive ? '대화 대기 중…' : '녹음 준비…');
    _startListening(maxMs: _isLlmActive ? _llmMaxListenMs : _defaultTurnMax.inMilliseconds);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Listening
  Future<void> _startListening({required int maxMs}) async {
    if (!_isOwner) return;
    if (!mounted || _state == VoiceState.listening) return;

    final now0 = DateTime.now().millisecondsSinceEpoch;
    final delta = now0 - _speakEndedAtMs;
    if (_speakEndedAtMs > 0 && delta < _postTtsGuardMs) {
      await Future.delayed(Duration(milliseconds: _postTtsGuardMs - delta));
    }

    try {
      final ok = await _recorder.hasPermission();
      if (!ok) {
        _setStatus('마이크 권한 필요');
        _setState(VoiceState.idle);
        _scheduleNextTurn(_cooldownMs);
        return;
      }

      if (_state == VoiceState.speaking) {
        await _player.stop();
      }

      _setState(VoiceState.listening);
      _disarmIdle();
      _markActivity();

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/moring_turn.wav';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
        path: path,
      );

      _recordStartMs = DateTime.now().millisecondsSinceEpoch;
      _lastLoudMs = _recordStartMs;
      _consecLoud = 0;
      _voicedMs = 0;
      _speechActive = false;
      _didBumpThisTurn = false;
      _interruptLoudFrames = 0;

      await Future.delayed(const Duration(milliseconds: _warmupMs));

      _ampSub?.cancel();
      _ampSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: _ampWindowMs))
          .listen((amp) async {
        if (!mounted || !_isOwner) return;

        _lastAmpDb = amp.current;

        if (_state == VoiceState.speaking) {
          if (amp.current.isFinite && amp.current > _vadDb) {
            _interruptLoudFrames++;
            if (_interruptLoudFrames >= _needFramesToInterrupt) {
              _interruptLoudFrames = 0;
              await _player.stop();
            }
          } else {
            _interruptLoudFrames = 0;
          }
          return;
        }

        final now = DateTime.now().millisecondsSinceEpoch;
        final loud = amp.current.isFinite && amp.current > _vadDb;

        if (loud) {
          _markActivity();
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

      while (mounted && _isOwner && _state == VoiceState.listening) {
        await Future.delayed(const Duration(milliseconds: 100));

        final now = DateTime.now().millisecondsSinceEpoch;
        final elapsed = now - _recordStartMs;
        final sinceLoud = now - _lastLoudMs;

        final minOk = elapsed >= _minListenMs;
        final silentAfterSpeech = _speechActive && sinceLoud >= _silenceTimeoutMs;
        final overMax = elapsed >= maxMs;
        final noSpeechTimeoutHit =
            !_speechActive && elapsed >= (_isLlmActive ? _noSpeechTimeoutLlmMs : _noSpeechTimeoutWakeMs);

        if ((minOk && silentAfterSpeech) || noSpeechTimeoutHit || overMax) break;
      }

      if (mounted && _isOwner && _state == VoiceState.listening) {
        await _stopAndProcess(filePath: path);
      }
    } catch (_) {
      _setStatus('녹음 시작 오류');
      if (mounted && _isOwner) {
        _setState(VoiceState.idle);
        _scheduleNextTurn(_cooldownMs);
      }
    }
  }

  Future<void> _stopAndProcess({required String? filePath}) async {
    if (!_isOwner) return;
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

      final whisperRes = await _callWhisperStt(f);

      STTResult finalRes = whisperRes;
      if (_shouldFallbackToClova(whisperRes)) {
        final clovaText = await _callClovaStt(f);
        if (clovaText.isNotEmpty) {
          final clovaConf = _estimateKoreanConfidence(clovaText);
          if (clovaConf >= whisperRes.confidence ||
              _koreanRatio(clovaText) > _koreanRatio(whisperRes.text)) {
            finalRes = STTResult(clovaText, clovaConf, 'clova');
          }
        }
      }

      _lastHeard = _sanitizeStt(finalRes.text.trim(), lastAssistant: _lastAssistant);
      if (_lastHeard.isEmpty) {
        _handleEmptyTurn();
        return;
      }

      // 에코 가드
      if (_isAssistantEcho(_lastHeard)) {
        if (kDebugMode) debugPrint('[Voice] echo guarded: "${_lastHeard}"');
        _setState(VoiceState.idle);
        _scheduleNextTurn(_cooldownMs);
        return;
      }

      _emptyTurns = 0;

      if (!_isLlmActive) {
        await _checkForWakeWord(_lastHeard);
      } else {
        await _handleLlmConversation(_lastHeard);
      }

      if (mounted && _isOwner && _state != VoiceState.speaking && !_llmBusy) {
        _setState(VoiceState.idle);
        _scheduleNextTurn(_cooldownMs);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Voice] 처리 오류: $e');
      _setStatus('처리 오류');
      if (mounted && _isOwner) {
        _setState(VoiceState.idle);
        _scheduleNextTurn(_cooldownMs);
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // STT
  Future<STTResult> _callWhisperStt(File wav) async {
    if (_gmsKey.isEmpty) {
      if (kDebugMode) debugPrint('[STT] GMS_KEY 미설정');
      return STTResult('', 0.0, 'whisper');
    }
    try {
      final form = FormData.fromMap({
        'model': _whisperModel,
        'file': await MultipartFile.fromFile(wav.path, filename: 'audio.wav'),
        'language': _whisperLanguage,
        'response_format': 'verbose_json',
        'prompt': '한국어 일상 대화, 자동차 내비게이션 맥락. 자연스러운 띄어쓰기.',
        'temperature': '0',
      });

      final res = await _plainDio.post(
        _whisperUrl,
        data: form,
        options: Options(
          headers: {'Authorization': 'Bearer $_gmsKey'},
          responseType: ResponseType.json,
          validateStatus: (s) => s != null && s < 500,
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
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
      return STTResult('', 0.0, 'whisper');
    } catch (e) {
      if (kDebugMode) debugPrint('[Whisper] 예외: $e');
      return STTResult('', 0.0, 'whisper');
    }
  }

  double _estimateWhisperConfidence(Map<String, dynamic> verboseJson, String text) {
    if (text.trim().isEmpty) return 0.0;
    double score = 0.4;
    final len = text.runes.length;
    if (len >= 6) score += 0.1;
    if (len >= 12) score += 0.1;
    score += (_koreanRatio(text) * 0.2);

    final segments = (verboseJson['segments'] as List?)?.cast<Map<String, dynamic>>();
    if (segments != null && segments.isNotEmpty) {
      double sumProb = 0; int c = 0;
      for (final s in segments) {
        final lp = (s['avg_logprob'] as num?)?.toDouble();
        if (lp != null) {
          final mapped = ((lp + 1.5) / 1.4).clamp(0.0, 1.0);
          sumProb += mapped; c++;
        }
      }
      if (c > 0) score = max(score, sumProb / c);
      if (len <= 3) score = min(score, 0.35);
    }
    final comp = (verboseJson['compression_ratio'] as num?)?.toDouble();
    if (comp != null && comp > 2.4) score = min(score, 0.45);
    return score.clamp(0.0, 1.0);
  }

  double _koreanRatio(String s) {
    if (s.isEmpty) return 0.0;
    final total = s.runes.length;
    final korean = RegExp(r'[가-힣]').allMatches(s).fold<int>(
      0, (p, m) => p + (m.group(0)?.runes.length ?? 0),
    );
    return korean / total;
  }

  Future<String> _callClovaStt(File wavFile) async {
    if (_clovaClientId.isEmpty || _clovaClientSecret.isEmpty) return '';
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
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
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
    } catch (_) { return ''; }
  }

  bool _shouldFallbackToClova(STTResult whisper) {
    if (_clovaClientId.isEmpty || _clovaClientSecret.isEmpty) return false;
    final text = whisper.text.trim();
    if (text.isEmpty) return true;
    final confLow = whisper.confidence < 0.58;
    final shortText = text.runes.length <= 2;
    final lowKorean = _koreanRatio(text) < 0.35;
    final hasWeird = RegExp(r'[A-Za-z]{3,}').hasMatch(text);
    return confLow || shortText || (lowKorean && hasWeird);
  }

  double _estimateKoreanConfidence(String text) {
    if (text.trim().isEmpty) return 0.0;
    double score = 0.5;
    final len = text.runes.length;
    if (len >= 6) score += 0.1;
    if (len >= 12) score += 0.1;
    score += _koreanRatio(text) * 0.2;
    return score.clamp(0.0, 1.0);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 대화 흐름
  Future<void> _handleEmptyTurn() async {
    if (!_isOwner) return;
    if (!mounted) return;

    if (_isLlmActive) {
      _emptyTurns++;
      if (_emptyTurns >= _emptyTurnsToExit) {
        _isLlmActive = false;
        _disarmIdle();
        _emptyTurns = 0;
        await _speakOpenAiTts('난중에, 대화가 필요하면 다시 불러줘.');
      } else {
        _armIdle(_llmGraceAfterWake);
        await _speakOpenAiTts('듣고 있어. 더 할 말 있으면 말해줘?');
      }
    } else {
      _setState(VoiceState.idle);
      _scheduleNextTurn(_cooldownMs);
    }
  }

  Future<void> _checkForWakeWord(String heardText) async {
    if (!_isOwner) return;
    final userText = _extractAfterWakeWord(heardText);
    if (userText != null) {
      // → LLM 모드 진입
      if (!_isLlmActive) setState(() => _isLlmActive = true);
      _disarmIdle();

      final trimmed = _sanitizeStt(userText).trim();
      if (trimmed.isEmpty) {
        // 웨이크워드만
        await _speakOpenAiTts('네, 말씀하세요.');
        _armIdle(_llmGraceAfterWake);
        _setState(VoiceState.idle);
        _scheduleNextTurn(_cooldownMs);
        return;
      }
      await _handleLlmConversation(trimmed);
    } else {
      _setState(VoiceState.idle);
      _scheduleNextTurn(_cooldownMs);
    }
  }

  Future<void> _handleLlmConversation(String heardText) async {
    if (!_isOwner) return;
    final raw = heardText.trim();
    if (raw.isEmpty) return;

    // ⬇️ 중첩 방지: 진행 중이면 최신 1건으로 교체 후 리턴
    if (_llmBusy) {
      _queuedUserText = raw;
      return;
    }
    _llmBusy = true;

    if (_llmExitWords.any((w) => raw.contains(w))) {
      _isLlmActive = false;
      _disarmIdle();
      await _speakOpenAiTts('대화를 종료합니다.');
      // _llmBusy 해제는 onPlayerStateChanged에서
      return;
    }

    final afterWake = _extractAfterWakeWord(raw);
    final userSaid = (afterWake ?? raw).trim();
    if (userSaid.isEmpty) {
      await _speakOpenAiTts('네, 말씀하세요.');
      return;
    }

    _disarmIdle();
    _markActivity();
    _setStatus('LLM 요청 중…');

    final prompt = _buildConversationalQuestion(userSaid);
    final answer = await _callLlm(prompt);
    _lastReply = answer.trim();
    _lastAssistant = _lastReply;
    _markActivity();

    _pushHistory('user', userSaid);
    if (_lastReply.isNotEmpty) _pushHistory('assistant', _lastReply);

    if (_lastReply.isNotEmpty) {
      await _speakOpenAiTts(_lastReply);
    } else {
      await _speakOpenAiTts('지금 네트워크가 불안정해요. 잠시 후 다시 말씀해 주세요.');
      _llmBusy = false; // 실패 시 직접 해제
      _setState(VoiceState.idle);
      _scheduleNextTurn(_cooldownMs);
    }
  }

  void _armIdle([Duration? dur]) {
    if (!_isOwner) return;
    if (!_isLlmActive) return;

    final d = dur ?? _llmIdle;
    _idleGen++;
    final myGen = _idleGen;

    final armedAt = DateTime.now().millisecondsSinceEpoch;

    _llmIdleTimer?.cancel();
    _llmIdleTimer = Timer(d, () async {
      if (!mounted || !_isOwner || myGen != _idleGen) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final lastActive = (_lastActivityMs > 0) ? _lastActivityMs : armedAt;
      final quietForMs = now - lastActive;

      final stillQuiet = quietForMs >= d.inMilliseconds - 200;
      final isSafeToEnd = _isLlmActive && _state == VoiceState.idle && _looping && stillQuiet;

      if (!isSafeToEnd) {
        _armIdle(d);
        return;
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

  // 웨이크워드 추출(강화)
  String? _extractAfterWakeWord(String text) {
    if (text.isEmpty) return null;

    var cleanedHead = text
        .replaceAll(RegExp(r'^[\s·…~,\.\-:;!?]+', unicode: true), '')
        .replaceAll(RegExp(r'^(어|음|에|저기|그|아)+\s*', unicode: true), '');

    final compact =
    cleanedHead.replaceAll(RegExp(r'[\s\p{P}]+', unicode: true), '');
    for (final w in _wakeWords) {
      final iCompact = compact.indexOf(w);
      if (iCompact >= 0 && iCompact <= 8) {
        final iRaw = cleanedHead.indexOf(w);
        if (iRaw >= 0) {
          final rest = cleanedHead.substring(iRaw + w.length).trim();
          return rest;
        }
      }
    }
    return null;
  }

  String _buildConversationalQuestion(String userText) {
    final buf = StringBuffer();
    buf.writeln('너는 "모링"이라는 이름을 가진 친절하고 상냥한 자동차 AI 어시스턴트야.');
    buf.writeln('항상 명확하고 간결하게, 그리고 반말로 대답해야 해. 사용자는 너의 친구야.');
    buf.writeln('자동차 네비게이션, 운전, 교통 상황과 관련된 질문에 특히 전문적으로 답변할 수 있어.');
    buf.writeln('');

    if (_history.isNotEmpty) {
      buf.writeln('--- 대화 맥락 ---');
      final start = _history.length > _maxTurnsMemory
          ? _history.length - _maxTurnsMemory
          : 0;
      for (int i = start; i < _history.length; i++) {
        final h = _history[i];
        final prefix = h['role'] == 'user' ? '친구' : '모링';
        buf.writeln('$prefix: ${h['content']}');
      }
      buf.writeln('--- 여기까지가 대화 맥락이야 ---');
      buf.writeln('');
    }

    buf.writeln('친구: $userText');
    buf.writeln('모링:');
    if (kDebugMode) debugPrint('[LLM Prompt]\n${buf.toString()}');
    return buf.toString();
  }

  void _pushHistory(String role, String content) {
    _history.add({'role': role, 'content': content});
    if (_history.length > _maxTurnsMemory * 2) {
      _history.removeRange(0, _history.length - _maxTurnsMemory * 2);
    }
  }

  // LLM 호출
  Future<String> _callLlm(String prompt) async {
    try {
      Dio apiClient;
      try {
        apiClient = ref.read(authDioProvider);
      } catch (_) {
        apiClient = ref.read(noAuthDioProvider);
      }

      Response res = await apiClient.post(
        _llmPath,
        data: {'question': prompt},
        options: Options(
          headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
          responseType: ResponseType.json,
          validateStatus: (s) => s != null && s < 500,
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
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
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      ans = _extractLlmResult(res);
      return ans ?? '';
    } catch (e) {
      if (kDebugMode) debugPrint('[LLM] 호출 실패: $e');
      return '';
    }
  }

  String? _extractLlmResult(Response res) {
    if (res.statusCode == 200) {
      final data = res.data;
      if (data is Map && data['result'] is String) return (data['result'] as String).trim();
      if (data is String) return data.trim();
    }
    return null;
  }

  // TTS
  Future<void> _speakOpenAiTts(String text) async {
    if (!_isOwner) return;
    if (!mounted || text.trim().isEmpty) return;
    if (_gmsKey.isEmpty) {
      if (kDebugMode) debugPrint('[TTS] GMS_KEY 미설정');
      return;
    }

    _disarmIdle();
    _markActivity();
    _setState(VoiceState.speaking);
    _setStatus('음성 답변 중…');

    try {
      final body = {'model': _ttsModel, 'input': text, 'voice': _ttsVoice, 'response_format': 'mp3'};

      final res = await _plainDio.post(
        _ttsUrl,
        data: jsonEncode(body),
        options: Options(
          headers: {'Authorization': 'Bearer $_gmsKey', 'Content-Type': 'application/json'},
          responseType: ResponseType.bytes,
          validateStatus: (s) => s != null && s < 500,
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      if (!mounted) return;

      if (res.statusCode == 200 && res.data != null) {
        final bytes = Uint8List.fromList(res.data as List<int>);
        _disarmIdle();
        _markActivity();
        await _player.play(BytesSource(bytes));
      } else {
        _llmBusy = false; // 실패 시 락 해제
        _setState(VoiceState.idle);
        _scheduleNextTurn(_cooldownMs);
      }
    } catch (_) {
      _llmBusy = false; // 예외 시 락 해제
      if (mounted && _isOwner) {
        _setState(VoiceState.idle);
        _scheduleNextTurn(_cooldownMs);
      }
    }
  }

  // STT 사후 정제
  String _sanitizeStt(String text, {String? lastAssistant}) {
    final original = text;
    String s = text;

    s = s.replaceAll(RegExp(r'[\[\(][^\]\)]{0,20}[\]\)]'), '');
    for (final p in _sttBlacklistExact) {
      s = s.replaceAll(RegExp(RegExp.escape(p), caseSensitive: false), '');
    }
    s = s.replaceAll(RegExp(r'^(모링|친구)\s*[:：]\s*', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'([가-힣A-Za-z0-9])\1{2,}'), r'\1\1');
    s = s.replaceAll(RegExp(r'\b([가-힣A-Za-z]{1,4})\b(?:\s*\1\b){2,}'), r'\1');
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    s = s.replaceAll(RegExp(r'^[\.\s,;:~…·\-]+|[\.\s,;:~…·\-]+$'), '').trim();

    if (s.isEmpty) return original.trim();

    if (lastAssistant != null && lastAssistant.trim().isNotEmpty) {
      final a = _normalize(lastAssistant);
      final b = _normalize(s);
      if (a == b) return original.trim();
    }

    if (_sttBlacklistExact.contains(s)) return '';
    for (final re in _sttBlacklistPatterns) {
      if (re.hasMatch(s)) return '';
    }
    if (s.length <= 3 && (s.contains('맥락') || s.contains('내비'))) return '';

    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  // 에코 가드
  bool _isAssistantEcho(String userText) {
    if (_lastAssistant.trim().isEmpty) return false;
    final a = _normalize(_lastAssistant);
    final b = _normalize(userText);
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;
    final sim = _jaccardSetSim(a, b);
    return sim >= 0.85 || (b.length <= 12 && a.contains(b));
  }

  String _normalize(String s) =>
      s.replaceAll(RegExp(r'[\s\.,;:!?~"\(\)\[\]\{\}…·\-]+'), '').toLowerCase();

  double _jaccardSetSim(String a, String b) {
    Set<String> grams(String x) {
      final g = <String>{};
      for (int i = 0; i < x.length - 1; i++) {
        g.add(x.substring(i, i + 2));
      }
      return g.isEmpty ? {x} : g;
    }
    final sa = grams(a);
    final sb = grams(b);
    final inter = sa.intersection(sb).length.toDouble();
    final union = sa.union(sb).length.toDouble();
    if (union == 0) return 0.0;
    return inter / union;
  }

  void _setStatus(String s) {
    if (mounted && (widget.showDebugPanel || widget.showBadge)) {
      setState(() => _status = s);
    }
  }

  // UI
  bool _shouldShowBadge() {
    if (!widget.showBadge || !_isOwner) return false;
    if (!widget.showBadgeOnlyWhenActive) return true;
    return _isLlmActive;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showDebugPanel && !widget.showBadge) return const SizedBox.shrink();
    if (!_isOwner) return const SizedBox.shrink();

    final children = <Widget>[];

    if (_shouldShowBadge()) {
      final (IconData icon, Color bgColor, String label) = switch (_state) {
        VoiceState.listening => _isLlmActive
            ? (Icons.hearing, Colors.blue, '듣는 중')
            : (Icons.mic, Colors.lightBlueAccent, '듣는 중'),
        VoiceState.processing => (Icons.psychology_outlined, Colors.orangeAccent, '생각 중'),
        VoiceState.speaking => (Icons.volume_up, Colors.greenAccent, '말하는 중'),
        VoiceState.idle => (Icons.chat_bubble_outline, Colors.blueGrey, '대화 대기'),
      };

      final isBottom = widget.badgeAlignment.y >= 0.9;
      final extraBottom = isBottom ? widget.avoidBottomPx : 0.0;

      children.add(
        Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: SafeArea(
              child: Align(
                alignment: widget.badgeAlignment,
                child: Padding(
                  padding: widget.badgeMargin.add(EdgeInsets.only(bottom: extraBottom)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: bgColor.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4))],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: Icon(icon, key: ValueKey<IconData>(icon),
                              color: Colors.black.withOpacity(0.7), size: 20),
                        ),
                        const SizedBox(width: 8),
                        Text(label,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (widget.showDebugPanel) {
      children.add(
        Positioned(
          right: 12, top: 12,
          child: Material(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12), width: 300,
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white, fontSize: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Voice: $_status'),
                    const SizedBox(height: 6),
                    Text('state: $_state, llm: $_isLlmActive, busy: $_llmBusy'),
                    const SizedBox(height: 6),
                    Text('amp: ${_lastAmpDb.isFinite ? _lastAmpDb.toStringAsFixed(1) : '–'} dB'),
                    const SizedBox(height: 6),
                    Text('heard: $_lastHeard', maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text('reply: $_lastReply', maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Stack(children: children);
  }
}
