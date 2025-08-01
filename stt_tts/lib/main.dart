import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // Uint8List를 위해 추가

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart'; // 오디오 재생을 위해 추가

void main() {
  runApp(const MyApp());
}

// Clova Speech API의 정확한 STT 요청 URL
const CLOVA_SPEECH_URL = 'https://naveropenapi.apigw.ntruss.com/recog/v1/stt';

// TODO: 여기에 실제 클로바 STT API 키를 입력하세요!
const CLOVA_CLIENT_ID = 'vrzfsc9dtl'; // 실제 Clova Client ID로 교체하세요
const CLOVA_CLIENT_SECRET = 'kRKt1yxbapvSObs8RfcaTzcSvHRYUqViWfehaqzW'; // 실제 Clova Client Secret으로 교체하세요

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clova STT & Google Cloud TTS Demo',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final record = AudioRecorder();
  String recognizedText = '';
  String messageText = '';
  bool isRecording = false; // 녹음 상태를 관리하는 변수
  bool isProcessing = false; // STT/TTS 처리 중 상태

  final AudioPlayer _audioPlayer = AudioPlayer(); // Google Cloud TTS 오디오 재생용
  // TODO: 여기에 발급받은 Google Cloud Text-to-Speech API 키를 입력하세요!
  // **경고: 프로덕션 앱에서는 API 키를 클라이언트 앱에 직접 하드코딩하지 마세요!**
  // 백엔드 서버를 통해 API 호출을 프록시하는 것이 가장 안전합니다.
  final String _googleCloudApiKey = "AIzaSyClE1u-E_3ZTuiinXyHNmsmWPuRuQ392Lk"; // <-- 여기에 Google Cloud API 키 입력

  String? _currentRecordingPath; // 현재 녹음 파일 경로 저장

  @override
  void initState() {
    super.initState();
    _checkMicrophonePermission();
  }

  // 마이크 권한 확인 함수
  Future<void> _checkMicrophonePermission() async {
    bool hasPermission = await record.hasPermission();
    print('[STT_TTS_DEMO_LOG] 마이크 권한 확인 결과: $hasPermission');
    if (!hasPermission) {
      _logEvent('마이크 권한이 필요합니다. 앱 사용 중 권한 요청 팝업이 나타날 것입니다.');
    } else {
      _logEvent('마이크 권한이 이미 허용되었습니다.');
    }
  }

  // 음성 녹음 시작 함수
  Future<void> startRecording() async {
    setState(() {
      isRecording = true;
      isProcessing = false; // 녹음 시작 시 처리 중 상태는 아님
      recognizedText = ''; // 이전 텍스트 초기화
      messageText = '녹음 준비 중...';
    });

    final dir = await getTemporaryDirectory();
    _currentRecordingPath = '${dir.path}/record.wav';
    _logEvent('녹음 파일 경로: $_currentRecordingPath');

    try {
      bool hasMicPermission = await record.hasPermission();
      if (hasMicPermission) {
        await record.start(const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000), path: _currentRecordingPath!);
        _logEvent('녹음 시작됨. 말씀하세요.');
        setState(() { messageText = '녹음 중... 말씀하세요.'; });
      } else {
        _logEvent('마이크 권한이 없어 녹음을 시작할 수 없습니다. 앱 설정에서 권한을 허용해주세요.');
        setState(() {
          isRecording = false;
          messageText = '마이크 권한 없음.';
        });
      }
    } catch (e) {
      _logEvent('녹음 시작 중 예외 발생: $e');
      setState(() {
        isRecording = false;
        messageText = '녹음 시작 중 오류 발생.';
      });
    }
  }

  // 음성 녹음 정지 및 STT/TTS 처리 함수
  Future<void> stopRecordingAndProcess() async {
    if (!isRecording) return; // 녹음 중이 아니면 아무것도 하지 않음

    setState(() {
      isRecording = false;
      isProcessing = true; // 녹음 중지 후 처리 시작
      messageText = '녹음 중지됨. 음성 인식 중...';
    });

    try {
      await record.stop();
      _logEvent('녹음 중지됨.');

      if (_currentRecordingPath == null) {
        _logEvent('오류: 녹음 파일 경로가 없습니다.');
        setState(() {
          isProcessing = false;
          messageText = '오류: 녹음 파일 경로 없음.';
        });
        return;
      }

      File audioFile = File(_currentRecordingPath!);
      if (!await audioFile.exists() || await audioFile.length() == 0) {
        _logEvent('오류: 녹음된 오디오 파일을 찾을 수 없거나 크기가 0입니다. 마이크 입력이 없거나 녹음 실패.');
        setState(() {
          isProcessing = false;
          messageText = '오류: 오디오 파일 없음 또는 비어있음. 마이크를 확인해주세요.';
        });
        return;
      }
      _logEvent('녹음 파일 존재 및 크기 확인: ${await audioFile.exists()}, ${await audioFile.length()} bytes');

      // 1. Clova Speech API 호출 (STT)
      _logEvent('Clova STT API 호출 시작...');
      final sttResult = await callClovaSpeech(audioFile);
      setState(() {
        recognizedText = sttResult; // STT 결과 업데이트
        messageText = '음성 인식이 완료되었습니다.';
      });
      _logEvent('인식된 텍스트: "$sttResult"');

      // 2. Google Cloud TTS 호출 (STT 결과가 있을 경우에만)
      if (sttResult.isNotEmpty && !sttResult.startsWith('[STT 오류')) {
        _logEvent('Google Cloud TTS 호출 시작...');
        await _speakText(sttResult); // 인식된 텍스트를 TTS로 재생
      }

    } catch (e) {
      _logEvent('음성 인식/처리 중 예외 발생: $e');
      setState(() {
        recognizedText = '오류 발생: $e';
        messageText = '음성 인식 중 오류가 발생했습니다.';
      });
    } finally {
      setState(() {
        isProcessing = false;
      });
      // 임시 파일 삭제 (필요시 주석 해제하여 자동 삭제)
      // try {
      //   if (_currentRecordingPath != null) {
      //     final fileToDelete = File(_currentRecordingPath!);
      //     if (await fileToDelete.exists()) {
      //       await fileToDelete.delete();
      //       _logEvent('녹음 파일 삭제됨: $_currentRecordingPath');
      //     }
      //   }
      // } catch (e) {
      //   _logEvent('임시 파일 삭제 중 오류 발생: $e');
      // }
      _currentRecordingPath = null; // 경로 초기화
    }
  }

  // Clova Speech API 호출 함수
  Future<String> callClovaSpeech(File audioFile) async {
    if (CLOVA_CLIENT_ID.isEmpty || CLOVA_CLIENT_SECRET.isEmpty) {
      _logEvent('클로바 API 키가 설정되지 않았습니다. CLOVA_CLIENT_ID 또는 CLOVA_CLIENT_SECRET을 확인해주세요.');
      return '[API 키 설정 필요]';
    }

    try {
      final uri = Uri.parse(CLOVA_SPEECH_URL).replace(queryParameters: {
        'lang': 'Kor',
      });

      final response = await http.post(
        uri,
        headers: {
          'X-NCP-APIGW-API-KEY-ID': CLOVA_CLIENT_ID,
          'X-NCP-APIGW-API-KEY': CLOVA_CLIENT_SECRET,
          'Content-Type': 'application/octet-stream',
        },
        body: await audioFile.readAsBytes(),
      );

      _logEvent('STT API 응답 상태 코드: ${response.statusCode}');
      _logEvent('STT API 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResult = json.decode(response.body);
        if (jsonResult.containsKey('text')) {
          return jsonResult['text'];
        } else if (jsonResult.containsKey('error')) {
          return '[STT 오류: ${jsonResult['error']['message'] ?? '알 수 없는 오류'}]';
        } else {
          return '[음성 인식 실패: 텍스트 없음 (응답 구조 이상)]';
        }
      } else {
        return '[STT 오류: ${response.statusCode}, ${response.body}]';
      }
    } catch (e) {
      _logEvent('STT API 호출 중 네트워크/통신 오류 발생: $e');
      return '[STT API 통신 오류: $e]';
    }
  }

  // Google Cloud TTS 호출 및 재생 함수
  Future<void> _speakText(String text) async {
    if (text.isEmpty) {
      print("TTS: 재생할 텍스트가 없습니다.");
      return;
    }
    if (_googleCloudApiKey.isEmpty || _googleCloudApiKey == "YOUR_GOOGLE_CLOUD_TTS_API_KEY") {
      _logEvent('Google Cloud TTS API 키가 설정되지 않았습니다. _googleCloudApiKey를 확인해주세요.');
      return;
    }

    final String url = "https://texttospeech.googleapis.com/v1/text:synthesize?key=$_googleCloudApiKey";

    final Map<String, dynamic> requestBody = {
      "input": {"text": text},
      "voice": {
        "languageCode": "ko-KR", // 한국어
        "name": "ko-KR-Wavenet-C", // Wavenet 음성 (더 자연스러움)
        "ssmlGender": "FEMALE" // 여성 음성
      },
      "audioConfig": {"audioEncoding": "MP3"} // MP3 형식으로 오디오 요청
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final String audioContent = responseData['audioContent']; // Base64 인코딩된 오디오 데이터

        // Base64 디코딩 및 오디오 재생
        final Uint8List decodedBytes = base64Decode(audioContent);
        await _audioPlayer.play(BytesSource(decodedBytes));
        _logEvent("TTS: 음성 재생 시작");
      } else {
        _logEvent("TTS: API 호출 실패: ${response.statusCode}, 응답: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("TTS 음성 생성 실패: ${response.statusCode}")),
        );
      }
    } catch (e) {
      _logEvent("TTS: 오류 발생: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("TTS 오류 발생: $e")),
      );
    }
  }

  void _logEvent(String message) {
    print('[STT_TTS_DEMO_LOG] $message');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    record.dispose();
    _audioPlayer.dispose(); // AudioPlayer도 dispose 해주어야 합니다.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('클로바 STT & Google Cloud TTS 데모'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 음성 인식 시작 버튼
            ElevatedButton.icon(
              onPressed: isRecording || isProcessing ? null : startRecording, // 녹음 중이거나 처리 중이면 비활성화
              icon: const Icon(Icons.mic),
              label: Text(isRecording ? '녹음 중...' : '음성 인식 시작'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isRecording ? Colors.orange : Colors.teal, // 녹음 중일 때 색상 변경
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 5,
              ),
            ),
            const SizedBox(height: 15),
            // 녹음 정지 버튼
            ElevatedButton.icon(
              onPressed: isRecording && !isProcessing ? stopRecordingAndProcess : null, // 녹음 중이고 처리 중이 아닐 때만 활성화
              icon: const Icon(Icons.stop),
              label: const Text('녹음 정지'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isRecording ? Colors.red : Colors.grey, // 녹음 중일 때 활성화 색상
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 5,
              ),
            ),
            const SizedBox(height: 30),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '상태:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      messageText.isEmpty ? '버튼을 눌러 음성 인식을 시작하세요.' : messageText,
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '인식된 텍스트:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recognizedText.isEmpty ? '여기에 음성 인식 결과가 표시됩니다.' : recognizedText,
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}