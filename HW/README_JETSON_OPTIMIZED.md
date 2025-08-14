# Jetson 최적화 드라이버 모니터링 시스템

## 개요
이 프로젝트는 NVIDIA Jetson 플랫폼에 최적화된 드라이버 모니터링 시스템입니다. CSI 카메라 지원, GPU 가속, 전력 최적화 등 Jetson 특화 기능을 포함합니다.

## 주요 기능

### Jetson 최적화 기능
- **CSI 카메라 지원**: GStreamer 파이프라인을 통한 CSI 카메라 자동 감지 및 설정
- **GPU 가속**: CUDA 기반 YOLO 추론 및 TensorRT 최적화 지원
- **전력 관리**: 자동 전력 모드 설정 및 클럭 최적화
- **성능 모니터링**: 실시간 FPS 및 GPU 사용률 모니터링

### 기존 기능
- **얼굴 인식**: 다중 각도 얼굴 등록 및 정확한 운전자 식별
- **졸음 감지**: Eye Aspect Ratio (EAR) 기반 실시간 졸음 감지
- **주의력 감지**: 고개 각도 및 시선 방향 분석
- **개인화된 임계값**: 운전자별 맞춤형 감지 임계값 적용
- **자동 설정**: 초기 실행 시 자동 얼굴 등록 및 베이스라인 측정

## 설치 방법

### 1. 자동 설치 (권장)
```bash
chmod +x install_jetson_optimized.sh
./install_jetson_optimized.sh
```

### 2. 수동 설치
```bash
# 시스템 패키지 업데이트
sudo apt update && sudo apt upgrade -y

# 필수 패키지 설치
sudo apt install -y python3-pip python3-dev python3-venv
sudo apt install -y libgstreamer1.0-0 gstreamer1.0-plugins-base gstreamer1.0-plugins-good

# Jetson 전력 모드 설정
sudo nvpmodel -m 2
sudo jetson_clocks

# Python 가상환경 생성
python3 -m venv jetson_env
source jetson_env/bin/activate

# Python 패키지 설치
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
pip install opencv-python mediapipe ultralytics face-recognition
```

## 설정

### config.json 설정
```json
{
    "jetson": {
        "camera_type": "usb",           // "usb" 또는 "csi"
        "enable_gpu_acceleration": true,
        "power_mode": 2,                // 0: 최대 성능, 2: 균형 모드
        "enable_jetson_clocks": true,
        "gpu_memory_fraction": 0.8,
        "tensorrt_optimization": false
    }
}
```

### 카메라 설정
- **USB 카메라**: `"camera_type": "usb"` (기본값)
- **CSI 카메라**: `"camera_type": "csi"`

## 사용법

### 기본 실행
```bash
source jetson_env/bin/activate
python driver_monitor_jetson.py
```

### GPU 가속 확인
```bash
python3 -c "import torch; print(torch.cuda.is_available())"
```

### 전력 모드 확인
```bash
sudo nvpmodel -q
```

## 성능 최적화

### 1. 전력 모드 설정
```bash
# 균형 모드 (권장)
sudo nvpmodel -m 2
sudo jetson_clocks

# 최대 성능 모드
sudo nvpmodel -m 0
sudo jetson_clocks
```

### 2. GPU 메모리 최적화
- `config.json`에서 `gpu_memory_fraction` 조정
- TensorRT 최적화 활성화 (고급 사용자)

### 3. 프레임 스킵 설정
- `skip_frames` 값을 조정하여 성능과 정확도 균형 조정
- 기본값: 2 (매 2프레임마다 1프레임 처리)

## 문제 해결

### 카메라 인식 문제
```bash
# 카메라 권한 확인
ls -la /dev/video*

# 권한 설정
sudo chmod 666 /dev/video*
sudo usermod -a -G video $USER
```

### GPU 가속 문제
```bash
# CUDA 설치 확인
nvidia-smi

# PyTorch CUDA 확인
python3 -c "import torch; print(torch.cuda.is_available())"
```

### CSI 카메라 문제
```bash
# GStreamer 파이프라인 테스트
gst-launch-1.0 nvarguscamerasrc ! nvvidconv ! videoconvert ! autovideosink
```

## 성능 벤치마크

### 테스트 환경
- **하드웨어**: Jetson Nano / Xavier NX / AGX Xavier
- **카메라**: USB Webcam / CSI Camera
- **해상도**: 640x480 (기본)

### 예상 성능
- **FPS**: 15-25 FPS (설정에 따라 다름)
- **GPU 사용률**: 60-80%
- **메모리 사용량**: 2-4GB

## 파일 구조
```
HW/
├── driver_monitor_jetson.py      # 메인 실행 파일
├── config_jetson.json            # Jetson 최적화 설정
├── install_jetson_optimized.sh   # 설치 스크립트
├── README_JETSON_OPTIMIZED.md    # 이 파일
├── data/                         # 데이터 디렉토리
│   ├── registered_faces.json     # 등록된 얼굴 데이터
│   ├── baseline.json            # 베이스라인 데이터
│   └── driver_thresholds.json   # 개인별 임계값
└── models/                       # 모델 디렉토리
    └── best.pt                   # YOLO 모델
```

## 라이선스
이 프로젝트는 MIT 라이선스 하에 배포됩니다.

## 지원
문제가 발생하면 다음을 확인하세요:
1. Jetson 전력 모드 설정
2. GPU 드라이버 버전
3. Python 패키지 버전 호환성
4. 카메라 권한 설정
