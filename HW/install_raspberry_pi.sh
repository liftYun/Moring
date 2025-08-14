#!/bin/bash

echo "=== 라즈베리파이 승인 요청 수신기 설치 스크립트 ==="

# 시스템 업데이트
echo "1. 시스템 패키지 업데이트..."
sudo apt update && sudo apt upgrade -y

# 필수 패키지 설치
echo "2. 필수 패키지 설치..."
sudo apt install -y python3-pip python3-dev python3-venv
sudo apt install -y git

# Python 가상환경 생성
echo "3. Python 가상환경 생성..."
python3 -m venv approval_env
source approval_env/bin/activate

# Python 패키지 설치
echo "4. Python 패키지 설치..."
pip install --upgrade pip
pip install paho-mqtt==1.6.1

# 디렉토리 생성
echo "5. 디렉토리 생성..."
mkdir -p approval_requests

# 실행 권한 설정
echo "6. 실행 권한 설정..."
chmod +x raspberry_pi_approval_receiver.py

echo "=== 설치 완료 ==="
echo "사용법:"
echo "1. 가상환경 활성화: source approval_env/bin/activate"
echo "2. 실행: python raspberry_pi_approval_receiver.py"
echo ""
echo "승인 요청이 오면 ./approval_requests/ 디렉토리에 저장됩니다."
echo "Ctrl+C로 종료할 수 있습니다."
