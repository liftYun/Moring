#!/bin/bash
echo "🚗 초간단 설치 시작!"

# 필수 패키지만 설치
echo "📦 필수 패키지 설치..."
pip3 install paho-mqtt requests python-dotenv

# 프로젝트 폴더
echo "📁 폴더 생성..."
mkdir -p ~/hw
cd ~/hw

# 설정 파일
echo "⚙️ 설정 파일 생성..."
cat > config.env << 'EOF'
MQTT_BROKER=43.203.216.22
MQTT_PORT=1883
MQTT_USERNAME=moring
MQTT_PASSWORD=kimoring
MQTT_CLIENT_ID=raspberry_pi_unified
CAR_VIN=KNMK5C2HMLP000437
SERVER_URL=https://i13e101.p.ssafy.io
API_ENDPOINT=/api/v1/notifications/send/general
SENSOR_INTERVAL=10
BUZZER_PIN=18
APPROVAL_DIR=./approval_requests
LOG_LEVEL=INFO
EOF

# 파일 복사
echo "📄 파일 복사..."
if [ -f "../raspberry_pi_simple.py" ]; then
    cp ../raspberry_pi_simple.py .
    echo "✅ raspberry_pi_simple.py 복사 완료"
else
    echo "⚠️ raspberry_pi_simple.py 파일을 찾을 수 없습니다"
fi

if [ -f "../config.json" ]; then
    cp ../config.json .
    echo "✅ config.json 복사 완료"
else
    echo "⚠️ config.json 파일을 찾을 수 없습니다"
fi

echo "✅ 완료!"
echo "🚀 실행: python3 raspberry_pi_simple.py"
