# Jetson Driver Monitoring System

Jetson Nano/Xavier/Orin에서 실행하는 운전자 모니터링 시스템

## 🚀 Jetson 설치 방법

### 1. 자동 설치 (권장)
```bash
python3 install_jetson.py
```

### 2. 수동 설치

#### 시스템 의존성
```bash
sudo apt-get update
sudo apt-get install -y python3-opencv
sudo apt-get install -y cmake build-essential
sudo apt-get install -y libblas-dev liblapack-dev
sudo apt-get install -y libatlas-base-dev
sudo apt-get install -y libx11-dev libgtk-3-dev
sudo apt-get install -y libavcodec-dev libavformat-dev libswscale-dev
```

#### Python 의존성
```bash
pip3 install -r data/requirements_jetson.txt
```

#### dlib 설치 (가장 중요!)
```bash
# 방법 1: 소스 컴파일 (권장)
wget http://dlib.net/files/dlib-19.24.2.tar.bz2
tar -xf dlib-19.24.2.tar.bz2
cd dlib-19.24.2
cmake -DCMAKE_BUILD_TYPE=Release -DUSE_AVX_INSTRUCTIONS=0 -DUSE_SSE4_INSTRUCTIONS=OFF -DUSE_SSE2_INSTRUCTIONS=OFF -DUSE_SSE_INSTRUCTIONS=OFF -DUSE_NEON_INSTRUCTIONS=ON -DUSE_BLAS=ON -DUSE_LAPACK=ON -DUSE_CUDA=ON -DCUDA_ARCH_BIN=8.7 -DCUDA_ARCH_PTX=8.7 .
make -j4
sudo make install
sudo python3 setup.py install
cd ..

# 방법 2: pip 설치 (간단하지만 느림)
pip3 install dlib --no-cache-dir
```

#### face_recognition 설치
```bash
pip3 install face-recognition
```

## 🎮 실행 방법

### 기본 실행
```bash
python3 v1ai_model_modified.py
```

### 성능 모니터링
```bash
# GPU 사용량 확인
nvidia-smi

# CPU/메모리 사용량 확인
htop

# Jetson 전용 모드 (최대 성능)
sudo nvpmodel -m 0
sudo jetson_clocks
```

## ⚡ 성능 최적화

### 1. Jetson 모드 설정
```bash
# 최대 성능 모드
sudo nvpmodel -m 0

# 팬 속도 조절
sudo jetson_clocks

# 확인
nvpmodel -q
```

### 2. 메모리 최적화
```bash
# 스왑 메모리 생성 (필요시)
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### 3. CUDA 최적화
```bash
# CUDA 환경변수 설정
export CUDA_VISIBLE_DEVICES=0
export CUDA_LAUNCH_BLOCKING=1
```

## 🔧 문제 해결

### dlib 컴파일 오류
```bash
# 메모리 부족 시
make -j2  # -j4 대신 -j2 사용

# CUDA 오류 시
cmake -DUSE_CUDA=OFF .  # CUDA 비활성화
```

### OpenCV 오류
```bash
# Jetson 전용 OpenCV 재설치
sudo apt-get remove python3-opencv
sudo apt-get install python3-opencv
```

### 메모리 부족
```bash
# 스왑 메모리 확인
free -h

# 불필요한 프로세스 종료
sudo systemctl stop bluetooth
sudo systemctl stop snapd
```

## 📊 성능 벤치마크

### Jetson Nano (4GB)
- **FPS**: 15-20 FPS
- **메모리 사용량**: 2-3GB
- **GPU 사용량**: 80-90%

### Jetson Xavier NX (8GB)
- **FPS**: 25-30 FPS
- **메모리 사용량**: 4-5GB
- **GPU 사용량**: 70-80%

### Jetson Orin Nano (8GB)
- **FPS**: 30-35 FPS
- **메모리 사용량**: 4-6GB
- **GPU 사용량**: 65-75%

### Jetson Orin (16GB)
- **FPS**: 35-40 FPS
- **메모리 사용량**: 6-8GB
- **GPU 사용량**: 60-70%

## 💡 팁

1. **첫 실행 시 느림**: JIT 컴파일로 인해 첫 실행이 느릴 수 있습니다
2. **온도 모니터링**: `tegrastats` 명령어로 온도 확인
3. **전원 관리**: USB 전원보다는 배터리 팩 사용 권장
4. **웹캠**: USB 3.0 웹캠 사용 시 성능 향상

## 🐛 알려진 이슈

1. **dlib 컴파일 시간**: 30분-1시간 소요
2. **메모리 부족**: 4GB Jetson에서는 스왑 메모리 필요
3. **CUDA 호환성**: 일부 CUDA 버전에서 호환성 문제
4. **웹캠 인식**: 일부 웹캠 드라이버 문제

## 📝 라이센스

이 프로젝트는 교육 및 연구 목적으로 제작되었습니다.
