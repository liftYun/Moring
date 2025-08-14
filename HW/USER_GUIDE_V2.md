ㄱ# 🚗 고급 운전자 모니터링 시스템 v2.0 사용 가이드

# 설치 전 필수 구성 요소

이 프로젝트는 `dlib` 및 `face_recognition`을 포함하고 있어 **Python 컴파일 환경이 필요합니다**.  
다른 컴퓨터에서 설치가 실패할 경우, 아래 구성 요소가 빠져 있을 수 있습니다.

## 1. 필수 구성 요소

### ⬛ Visual C++ Build Tools 설치 (필수)
- [공식 다운로드 링크](https://visualstudio.microsoft.com/visual-cpp-build-tools/)
- 설치 시 **다음 항목**을 선택하세요:
  - C++ build tools
  - Windows 10 SDK (또는 11)
  - MSVC v14.x (최신)

### ⬛ CMake 설치 (선택 필수)
- [CMake 다운로드 링크](https://cmake.org/download/)
- 설치 후, 시스템 PATH에 자동 등록되도록 설정

---

## 2. 설치 방법

Python 3.12.10 이상 환경에서 아래 명령어를 실행하세요:

```bash
python -m pip install --upgrade pip setuptools wheel
pip install -r requirements.txt



### 2. 실행
```bash
cd HW
python driver_monitor_v2.py
```

## 📋 목차
1. [시스템 개요](#시스템-개요)
2. [주요 개선사항](#주요-개선사항)
3. [설치 및 실행](#설치-및-실행)
4. [기본 사용법](#기본-사용법)
5. [고급 기능](#고급-기능)
6. [성능 최적화](#성능-최적화)
7. [문제 해결](#문제-해결)
8. [설정 파일](#설정-파일)

## 🎯 시스템 개요

### v2.0 주요 특징
- **클래스 기반 아키텍처**: 모듈화된 구조로 유지보수성 향상
- **설정 파일 관리**: JSON 기반 설정 시스템
- **성능 최적화**: 실시간 FPS 모니터링 및 최적화
- **비동기 처리**: 멀티스레드 YOLO 객체 감지
- **강화된 오류 처리**: 안정적인 시스템 운영
- **로깅 시스템**: 상세한 로그 기록

### 지원 환경
- **OS**: Windows 10/11, macOS, Linux
- **Python**: 3.8 이상
- **카메라**: 웹캠 또는 내장 카메라
- **GPU**: 선택사항 (CUDA 지원 시 성능 향상)

## 🚀 주요 개선사항

### 1. 클래스 기반 아키텍처
```
DriverMonitor (메인 클래스)
├── ConfigManager (설정 관리)
├── PerformanceMonitor (성능 모니터링)
├── FaceProcessor (얼굴 처리)
├── YOLODetector (객체 감지)
├── DetectionManager (감지 관리)
└── DisplayManager (화면 표시)
```

### 2. 성능 최적화
- **프레임 스킵**: 처리량 조절로 성능 향상
- **해상도 최적화**: 320x240 ~ 1280x720 지원
- **AI 모델 간격 조절**: 얼굴 인식, YOLO 감지 주기 조절
- **GPU 가속**: CUDA 지원으로 처리 속도 향상

### 3. 설정 파일 시스템
- **config.json**: 모든 설정을 JSON 파일로 관리
- **실시간 설정 변경**: 런타임에 설정 조절 가능
- **자동 저장/로드**: 설정 변경사항 자동 저장



## 🎮 기본 사용법

### 키보드 조작
| 키 | 기능 | 설명 |
|---|---|---|
| **R** | 얼굴 등록 | 현재 운전자 얼굴을 등록 |
| **I** | 얼굴 식별 | 현재 운전자 식별 |
| **B** | Baseline 측정 | 개인별 정상 상태 측정 (시간 선택) |
| **N** | 새 사용자 등록 | 10분간 개인 임계치 측정 |
| **P** | 성능 설정 | 성능 최적화 옵션 조절 |
| **S** | 설정 저장 | 현재 설정을 파일에 저장 |
| **L** | 설정 로드 | 파일에서 설정 로드 |
| **+/-** | 감도 조절 | 감지 임계치 증가/감소 |
| **C** | DB 초기화 | 등록된 데이터 삭제 |
| **H** | 도움말 | 사용법 안내 |
| **ESC** | 종료 | 프로그램 종료 |

### 베이스라인 측정 옵션 (B키)
1. **빠른 측정 (1분)**: 테스트용, 빠른 확인
2. **기본 측정 (5분)**: 일반적인 사용, 권장
3. **전체 측정 (10분)**: 정확한 데이터 수집
4. **사용자 지정**: 원하는 시간 설정 (30초~30분)

## 🔧 고급 기능

### 성능 설정 조절 (P키)

#### 1. 성능 모드 ON/OFF
- **ON**: 프레임 스킵, 해상도 최적화 적용
- **OFF**: 모든 프레임 처리, 최고 품질

#### 2. 프레임 스킵 조절 (1-5)
- **1**: 모든 프레임 처리 (최고 품질, 느림)
- **2**: 절반 프레임 처리 (권장)
- **3-5**: 더 적은 프레임 처리 (빠름, 품질 저하)

#### 3. 해상도 선택
- **320x240**: 최고 성능, 낮은 화질
- **640x480**: 권장 설정 (기본값)
- **1280x720**: 고화질, 느림

#### 4. AI 모델 간격 조절
- **얼굴 인식**: 10-60프레임마다 실행
- **YOLO 감지**: 5-30프레임마다 실행

#### 5. GPU 가속 ON/OFF
- **ON**: CUDA 지원 시 GPU 사용
- **OFF**: CPU만 사용

### 설정 저장/로드 (S/L키)
- **S키**: 현재 설정을 `config.json`에 저장
- **L키**: `config.json`에서 설정 로드

## ⚡ 성능 최적화

### 하드웨어별 최적 설정

#### 저사양 PC (CPU만)
```json
{
  "performance": {
    "performance_mode": true,
    "skip_frames": 3,
    "webcam_resolution": [320, 240],
    "face_recognition_interval": 60,
    "yolo_detection_interval": 30,
    "enable_gpu": false
  }
}
```

#### 중간 사양 PC
```json
{
  "performance": {
    "performance_mode": true,
    "skip_frames": 2,
    "webcam_resolution": [640, 480],
    "face_recognition_interval": 30,
    "yolo_detection_interval": 10,
    "enable_gpu": false
  }
}
```

#### 고사양 PC (GPU 있음)
```json
{
  "performance": {
    "performance_mode": true,
    "skip_frames": 1,
    "webcam_resolution": [1280, 720],
    "face_recognition_interval": 10,
    "yolo_detection_interval": 5,
    "enable_gpu": true
  }
}
```

### 성능 모니터링
- **실시간 FPS**: 화면에 현재 FPS 표시
- **프레임 처리 시간**: 평균/최소/최대 처리 시간
- **성능 병목 감지**: 자동 성능 분석

## 🛠️ 문제 해결

### 일반적인 문제들

#### 1. 렉이 심한 경우
```
해결 방법:
1. P키 → 성능 설정 조절
2. 해상도를 320x240으로 낮춤
3. 프레임 스킵을 3-5로 증가
4. AI 모델 간격을 늘림
5. GPU 가속 비활성화
```

#### 2. 얼굴 인식이 안 되는 경우
```
해결 방법:
1. 조명 확인 (밝은 곳에서 사용)
2. 카메라와의 거리 조절 (30-50cm)
3. 얼굴이 정면을 향하도록 조정
4. R키로 얼굴 재등록
5. 얼굴 인식 간격 조절
```

#### 3. 오탐지가 많은 경우
```
해결 방법:
1. B키로 베이스라인 재측정
2. +/-키로 감도 조절
3. 개인별 임계치 확인
4. 조명 환경 개선
5. 감지 임계치 조정
```

#### 4. 카메라 오류
```
해결 방법:
1. 다른 프로그램에서 카메라 사용 중지
2. 카메라 드라이버 재설치
3. USB 포트 변경
4. 관리자 권한으로 실행
5. 해상도 설정 확인
```

#### 5. YOLO 모델 오류
```
해결 방법:
1. models/best.pt 파일 존재 확인
2. GPU 메모리 부족 시 CPU 모드로 전환
3. YOLO 감지 간격 늘리기
4. 모델 파일 재다운로드
```

## 📁 설정 파일

### config.json 구조
```json
{
  "performance": {
    "performance_mode": true,
    "skip_frames": 2,
    "webcam_resolution": [640, 480],
    "face_recognition_interval": 30,
    "yolo_detection_interval": 10,
    "enable_gpu": false
  },
  "detection_thresholds": {
    "eye_ar_thresh": 0.27,
    "eye_ar_consec_frames": 5,
    "pitch_down_thresh": -160,
    "yaw_thresh": 90,
    "roll_thresh": 8,
    "gaze_consec_frames": 5,
    "phone_near_face_threshold_px": 100,
    "phone_consec_frames": 5,
    "gaze_to_phone_yaw_thresh": 30,
    "gaze_to_phone_pitch_thresh": -10,
    "face_recognition_threshold": 0.45
  },
  "baseline_config": {
    "duration_quick": 60,
    "duration_default": 300,
    "duration_full": 600
  }
}
```

### 데이터 파일 위치
```
HW/
├── driver_monitor_v2.py      # 메인 프로그램
├── config.json              # 설정 파일
├── driver_monitor.log       # 로그 파일
├── data/
│   ├── registered_faces.json    # 등록된 얼굴 데이터
│   ├── driver_thresholds.json   # 개인별 임계치
│   └── baseline.json           # 개인별 베이스라인
└── models/
    └── best.pt              # YOLO 모델 파일
```

## 📊 로그 시스템

### 로그 레벨
- **INFO**: 일반 정보 메시지
- **WARNING**: 경고 메시지
- **ERROR**: 오류 메시지
- **DEBUG**: 디버그 정보 (개발용)

### 로그 파일 확인
```bash
# 실시간 로그 확인
tail -f driver_monitor.log

# 오류만 확인
grep "ERROR" driver_monitor.log

# 성능 관련 로그 확인
grep "FPS\|Performance" driver_monitor.log
```

## 🔄 자동화 기능

### 자동 운전자 인식
- 시스템 시작 시 등록된 운전자 자동 감지
- 새로운 운전자 감지 시 자동 알림
- 개인별 임계치 자동 적용

### 자동 성능 최적화
- 하드웨어 성능에 따른 자동 설정 조절
- 실시간 성능 모니터링
- 성능 병목 자동 감지

### 자동 데이터 관리
- 설정 변경사항 자동 저장
- 개인별 데이터 자동 백업
- 오류 발생 시 자동 복구

## 📞 지원

### 문제 발생 시 확인사항
1. 로그 파일 확인 (`driver_monitor.log`)
2. 설정 파일 확인 (`config.json`)
3. 데이터 파일 확인 (`data/` 폴더)
4. 모델 파일 확인 (`models/best.pt`)

### 성능 문제 해결 순서
1. 성능 설정 조절 (P키)
2. 해상도 낮추기
3. 프레임 스킵 증가
4. AI 모델 간격 늘리기
5. GPU 가속 비활성화

### 연락처
- **로그 파일**: `driver_monitor.log` 확인
- **설정 파일**: `config.json` 수정
- **데이터 백업**: `data/` 폴더 백업

---

**💡 팁**: v2.0에서는 모든 설정이 파일로 관리되므로, 최적 설정을 찾은 후 S키로 저장해두면 다음 실행 시에도 동일한 설정이 적용됩니다.
