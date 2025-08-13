// lib/screens/navigation/alerts_sse_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';

import 'package:moring/providers/api_client.dart';
import 'package:moring/providers/current_car_provider.dart';
import 'package:moring/providers/token_repository.dart';

// ✅ moring_voice_auto의 VoiceAssistantPanel만 사용 (별칭)
import 'package:moring/screens/navigation/sse_with_voice.dart' as mva;

class AlertsSsePage extends ConsumerStatefulWidget {
  const AlertsSsePage({Key? key}) : super(key: key);

  @override
  ConsumerState<AlertsSsePage> createState() => _AlertsSsePageState();
}

class _AlertsSsePageState extends ConsumerState<AlertsSsePage> {
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
          // (삭제됨) VoiceDebugSimplePage 버튼
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

            // 🎙 음성 패널 (mva 별칭으로 명시)
             mva.VoiceAssistantPanel(
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
