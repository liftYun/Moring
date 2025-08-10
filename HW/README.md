# Driver Monitoring System

운전자 졸음 감지 및 시선 이탈 모니터링 시스템

## 📋 기능

- **졸음 감지**: 눈 감김 및 고개 떨굼 감지
- **시선 이탈 감지**: 고개 회전 및 기울기 감지  
- **휴대폰 사용 감지**: YOLO 기반 객체 감지
- **얼굴 인식**: 운전자 등록 및 식별
- **개인화된 감지**: 개인별 baseline 기반 임계값 조정
- **머신러닝 지원**: 하이브리드 감지 시스템 (v1ai_model_improved.py)

## 🚀 설치 방법

### 1. 의존성 설치

#### 자동 설치 (권장)
```bash
python install_dependencies.py
```

#### 수동 설치
```bash
pip install -r data/requirements.txt
```

### 2. 시스템 의존성

#### Windows
- Visual Studio Build Tools (dlib 컴파일용)

#### Linux
```bash
sudo apt-get install cmake build-essential
```

#### macOS
```bash
brew install cmake
```

## 📁 파일 구조

```
moring/
├── v1ai_model_modified.py      # 기본 버전 (규칙 기반)
├── v1ai_model_improved.py      # 고급 버전 (ML 지원)
├── install_dependencies.py     # 의존성 설치 스크립트
├── models/
│   └── best.pt                # YOLO 모델 파일
├── data/
│   ├── registered_faces.json  # 등록된 얼굴 데이터
│   ├── baseline.json          # 개인별 기준값
│   └── requirements.txt       # Python 패키지 목록
└── logs/                      # 로그 파일
```

## 🎮 사용 방법

### 기본 버전 실행
```bash
python v1ai_model_modified.py
```

### 머신러닝 버전 실행
```bash
python v1ai_model_improved.py --use_ml
```

### 사용자 지정 설정
```bash
python v1ai_model_modified.py --user_id "DriverA" --measure_time 300
```

## ⌨️ 키보드 컨트롤

| 키 | 기능 |
|---|---|
| `R` | 운전자 얼굴 등록 |
| `I` | 운전자 식별 |
| `B` | Baseline 재측정 |
| `+` | 감도 증가 |
| `-` | 감도 감소 |
| `1` | 정상 데이터 수집 (ML 모드) |
| `2` | 졸음 데이터 수집 (ML 모드) |
| `3` | 시선이탈 데이터 수집 (ML 모드) |
| `T` | ML 모델 훈련 (ML 모드) |
| `ESC` | 종료 |

## 🔧 설정 옵션

### 명령행 인자

- `--user_id`: 사용자 ID (기본값: "DriverA")
- `--measure_time`: baseline 측정 시간 (초, 기본값: 300)
- `--eye_ar_ratio`: 눈 EAR 비율 (기본값: 0.6)
- `--pitch_ratio`: 고개 Pitch 비율 (기본값: 2.0)
- `--yaw_ratio`: 고개 Yaw 비율 (기본값: 3.0)
- `--roll_ratio`: 고개 Roll 비율 (기본값: 2.0)
- `--use_ml`: 머신러닝 모드 활성화
- `--collect_data`: 데이터 수집 모드

## 📊 시스템 요구사항

- **Python**: 3.8 이상
- **RAM**: 최소 4GB (권장 8GB)
- **GPU**: 선택사항 (CUDA 지원 시 성능 향상)
- **웹캠**: 필수

## 🐛 문제 해결

### dlib 설치 오류
```bash
# Windows
pip install dlib --no-cache-dir

# Linux/macOS
pip install cmake
pip install dlib
```

### OpenCV 오류
```bash
# GUI 없는 시스템
pip install opencv-python-headless
```

### CUDA 지원 (선택사항)
```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
```

## 📝 라이센스

이 프로젝트는 교육 및 연구 목적으로 제작되었습니다.

## 🤝 기여

버그 리포트나 기능 제안은 이슈로 등록해주세요.
