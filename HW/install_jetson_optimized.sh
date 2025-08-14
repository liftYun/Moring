#!/bin/bash

echo "=== Jetson Driver Monitoring System 설치 스크립트 ==="

# 시스템 업데이트
echo "1. 시스템 패키지 업데이트..."
sudo apt update && sudo apt upgrade -y

# 필수 패키지 설치
echo "2. 필수 패키지 설치..."
sudo apt install -y python3-pip python3-dev python3-venv
sudo apt install -y libgstreamer1.0-0 gstreamer1.0-plugins-base gstreamer1.0-plugins-good
sudo apt install -y gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav
sudo apt install -y gstreamer1.0-tools gstreamer1.0-x gstreamer1.0-alsa gstreamer1.0-gl
sudo apt install -y gstreamer1.0-gtk3 gstreamer1.0-qt5 gstreamer1.0-pulseaudio
sudo apt install -y libgstreamer-plugins-base1.0-dev libgstreamer1.0-dev
sudo apt install -y libgstreamer-plugins-bad1.0-dev gstreamer1.0-plugins-base-apps
sudo apt install -y gstreamer1.0-plugins-good-doc gstreamer1.0-plugins-bad-doc
sudo apt install -y gstreamer1.0-plugins-ugly-doc gstreamer1.0-libav-doc
sudo apt install -y gstreamer1.0-tools-doc gstreamer1.0-x-doc gstreamer1.0-alsa-doc
sudo apt install -y gstreamer1.0-gl-doc gstreamer1.0-gtk3-doc gstreamer1.0-qt5-doc
sudo apt install -y gstreamer1.0-pulseaudio-doc

# Jetson 전용 패키지
echo "3. Jetson 전용 패키지 설치..."
sudo apt install -y nvidia-container-toolkit
sudo apt install -y libnvidia-compute-470

# Python 가상환경 생성
echo "4. Python 가상환경 생성..."
python3 -m venv jetson_env
source jetson_env/bin/activate

# Python 패키지 설치
echo "5. Python 패키지 설치..."
pip install --upgrade pip

# Jetson 최적화된 패키지들
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
pip install opencv-python==4.8.1.78
pip install mediapipe==0.10.7
pip install ultralytics==8.0.196
        pip install face-recognition==1.3.0
        pip install numpy==1.24.3
        pip install scipy==1.11.1
        pip install pillow==10.0.0
        pip install paho-mqtt==1.6.1

# Jetson 전력 모드 설정
echo "6. Jetson 전력 모드 설정..."
sudo nvpmodel -m 2
sudo jetson_clocks

# 권한 설정
echo "7. 권한 설정..."
sudo usermod -a -G video $USER
sudo chmod 666 /dev/video*

# 디렉토리 생성
echo "8. 디렉토리 생성..."
mkdir -p data models

# 설정 파일 복사
echo "9. 설정 파일 설정..."
if [ -f "config_jetson.json" ]; then
    cp config_jetson.json config.json
    echo "Jetson 설정 파일 적용 완료"
else
    echo "config_jetson.json 파일이 없습니다. 기본 설정을 사용합니다."
fi

echo "=== 설치 완료 ==="
echo "사용법:"
echo "1. 가상환경 활성화: source jetson_env/bin/activate"
echo "2. 실행: python driver_monitor_jetson.py"
echo ""
echo "CSI 카메라 사용 시 config.json에서 camera_type을 'csi'로 변경하세요."
echo "GPU 가속 확인: python3 -c 'import torch; print(torch.cuda.is_available())'"
