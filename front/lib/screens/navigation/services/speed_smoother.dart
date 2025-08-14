import 'dart:math';                                         // max() 등 수학 함수 사용

class SpeedSmoother {                                       // 공개 스무딩 클래스(다른 파일에서도 사용 가능)
  final double maxKmh;                                      // 허용 최대 속도(km/h) – 스파이크 컷 상한
  final double maxAccelKmhPerS;                             // 초당 허용 가속도(km/h/s) – 변화량 제한
  double? _ema;                                             // EMA 누적 값(현재 부드러워진 속도, km/h)
  DateTime? _lastTs;                                        // 마지막 입력 시각(EMA/가속도 제한에 필요)
  double _lastKmh = 0.0;                                    // 직전 속도(km/h) – 가속도 제한 계산용

  SpeedSmoother({                                           // 생성자: 파라미터 기본값 제공
    this.maxKmh = 180.0,                                    // 기본 상한 180km/h
    this.maxAccelKmhPerS = 35.0,                            // 기본 가속 상한 35km/h/s
  });

  static double msToKmh(double ms) => ms * 3.6;             // 도우미: m/s → km/h 변환

  /// 원시 속도(rawMs: m/s)와 시각(ts)을 받아 EMA/가속도 제한을 적용한 km/h를 반환
  double push({required double rawMs, required DateTime ts}) {
    double kmh = msToKmh(max(0.0, rawMs))                   // 1) 입력 m/s를 km/h로 변환 + 음수일 경우 0
        .clamp(0.0, maxKmh);                    //    말도 안 되는 큰 값은 상한으로 자름
    
    // 🆕 매우 낮은 속도는 노이즈로 간주하여 0으로 처리
    if (kmh < 2.0) kmh = 0.0;

    final dt = _lastTs == null
        ? 0.0                                               // 2) 이전 입력이 없으면 경과 시간 0초
        : ts.difference(_lastTs!).inMilliseconds / 1000.0;  //    있으면 초 단위 경과 시간 계산
    _lastTs = ts;                                           //    이번 입력 시각을 저장(다음 호출 대비)

    if (dt > 0 && _lastKmh > 0) {                           // 3) 가속도 제한: 이전 속도가 0 초과이고 시간이 흘렀을 때만
      final diff = kmh - _lastKmh;                          //    이번 속도 - 이전 속도 (변화량)
      final limit = maxAccelKmhPerS * dt;                   //    허용 변화량 = (초당 허용치) × (경과시간)
      if (diff.abs() > limit) {                             //    변화량이 허용치보다 크면
        kmh = _lastKmh + diff.sign * limit;                 //    허용 범위 안으로 잘라서 부드럽게
      }
    }

    final alpha = (0.25 + dt * 0.15)                        // 4) EMA 가중치 계산: dt가 클수록 더 빠르게 따라감
        .clamp(0.12, 0.6);                                  //    과도한 흔들림/느림 방지를 위해 범위 제한
    _ema = _ema == null                                     //    EMA 업데이트
        ? kmh                                               //    첫 값이면 그대로 채택
        : (_ema! + alpha * (kmh - _ema!));                  //    이후엔 이전 EMA에 변화분의 일부만 반영
    _lastKmh = _ema!;                                       //    다음 호출을 위한 "이전 속도" 갱신
    return _ema!;                                           //    부드러워진 속도(km/h)를 반환
  }

  void reset() {                                            // 내부 상태 초기화(재시작 시 깔끔한 반응을 위해)
    _ema = null;                                            // EMA 누적값 제거
    _lastTs = null;                                         // 마지막 시각 제거
    _lastKmh = 0.0;                                         // 마지막 속도 0으로 초기화
  }
}