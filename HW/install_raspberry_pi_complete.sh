#!/bin/bash
# 라즈베리파이 완전 설치 스크립트

echo "🚗 라즈베리파이 드라이버 모니터링 시스템 설치 시작"

# 시스템 업데이트
echo "📦 시스템 업데이트 중..."
sudo apt update && sudo apt upgrade -y

# 필수 패키지 설치
echo "📦 필수 패키지 설치 중..."
sudo apt install -y python3 python3-pip python3-venv git curl wget

# MQTT 브로커 설치 (로컬 테스트용)
echo "📡 MQTT 브로커 설치 중..."
sudo apt install -y mosquitto mosquitto-clients
sudo systemctl enable mosquitto
sudo systemctl start mosquitto

# MQTT 설정
echo "⚙️ MQTT 설정 중..."
sudo tee /etc/mosquitto/conf.d/default.conf > /dev/null <<EOF
listener 1883
allow_anonymous false
password_file /etc/mosquitto/passwd
EOF

# MQTT 사용자 생성
echo "👤 MQTT 사용자 생성 중..."
sudo mosquitto_passwd -c /etc/mosquitto/passwd moring
echo "kimoring" | sudo mosquitto_passwd -u /etc/mosquitto/passwd moring

# MQTT 브로커 재시작
sudo systemctl restart mosquitto

# Python 가상환경 생성
echo "🐍 Python 가상환경 생성 중..."
python3 -m venv venv
source venv/bin/activate

# Python 패키지 설치
echo "📦 Python 패키지 설치 중..."
pip install --upgrade pip

# 기본 패키지
pip install paho-mqtt requests python-dotenv

# 센서 라이브러리 (수정된 패키지명)
pip install mh-z19b
pip install dht22

# Adafruit_DHT 대체 설치 (실패 시)
if ! pip install Adafruit-DHT --force-pi; then
    echo "⚠️ Adafruit_DHT 설치 실패, 대체 라이브러리 사용"
    pip install dht22
    echo "✅ dht22 라이브러리 설치 완료"
else
    echo "✅ Adafruit_DHT 설치 완료"
fi

# 대안: git에서 직접 설치
if ! python3 -c "import Adafruit_DHT" 2>/dev/null; then
    echo "📦 Adafruit_DHT git에서 설치 중..."
    pip install git+https://github.com/adafruit/Adafruit_Python_DHT.git
fi

# GPIO 라이브러리
pip install RPi.GPIO

# 프로젝트 디렉토리 생성
echo "📁 프로젝트 디렉토리 생성 중..."
mkdir -p ~/hw
cd ~/hw

# 설정 파일 복사 (수정된 설정)
echo "⚙️ 설정 파일 생성 중..."
cat > config.env << 'EOF'
# MQTT 설정
MQTT_BROKER=43.203.216.22
MQTT_PORT=1883
MQTT_USERNAME=moring
MQTT_PASSWORD=kimoring
MQTT_CLIENT_ID=raspberry_pi_unified

# 차량 정보
CAR_VIN=KNMK5C2HMLP000437

# 서버 API 설정 (수정된 URL)
SERVER_URL=https://i13e101.p.ssafy.io
API_ENDPOINT=/api/v1/notifications/send/general

# 센서 설정
SENSOR_INTERVAL=10

# 부저 설정
BUZZER_PIN=18

# 승인 요청 저장 디렉토리
APPROVAL_DIR=./approval_requests

# 로그 설정
LOG_LEVEL=INFO
LOG_MAX_SIZE=10MB
LOG_BACKUP_COUNT=5
EOF

# Python 파일 복사 (현재 디렉토리에서)
echo "📄 Python 파일 복사 중..."
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

# systemd 서비스 파일 생성
echo "🔧 systemd 서비스 생성 중..."
sudo tee /etc/systemd/system/raspberry-pi-monitor.service > /dev/null <<EOF
[Unit]
Description=Raspberry Pi Driver Monitoring System
After=network.target mosquitto.service

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/hw
Environment=PATH=/home/pi/hw/venv/bin
ExecStart=/home/pi/hw/venv/bin/python3 raspberry_pi_simple.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 서비스 활성화
echo "🚀 서비스 활성화 중..."
sudo systemctl daemon-reload
sudo systemctl enable raspberry-pi-monitor.service

# 권한 설정
echo "🔐 권한 설정 중..."
sudo usermod -a -G gpio pi
sudo usermod -a -G video pi

# 센서 연결 가이드
echo "📋 센서 연결 가이드:"
echo "CO2 센서 (MH-Z19B):"
echo "  - VCC -> 5V"
echo "  - GND -> GND"
echo "  - TX -> GPIO 14 (UART)"
echo "  - RX -> GPIO 15 (UART)"
echo ""
echo "온습도 센서 (DHT22):"
echo "  - VCC -> 3.3V"
echo "  - GND -> GND"
echo "  - DATA -> GPIO 4"
echo ""
echo "부저:"
echo "  - VCC -> GPIO 18"
echo "  - GND -> GND"

# UART 활성화 (CO2 센서용)
echo "🔧 UART 활성화 중..."
sudo raspi-config nonint do_serial 0
sudo systemctl disable serial-getty@ttyAMA0.service

# 설치 완료
echo "✅ 설치 완료!"
echo ""
echo "📋 다음 단계:"
echo "1. 센서들을 연결하세요"
echo "2. 설정 파일을 수정하세요: nano ~/hw/config.json"
echo "3. 서비스를 시작하세요: sudo systemctl start raspberry-pi-monitor"
echo "4. 로그를 확인하세요: sudo journalctl -u raspberry-pi-monitor -f"
echo ""
echo "🔧 유용한 명령어:"
echo "  서비스 시작: sudo systemctl start raspberry-pi-monitor"
echo "  서비스 중지: sudo systemctl stop raspberry-pi-monitor"
echo "  로그 확인: sudo journalctl -u raspberry-pi-monitor -f"
echo "  상태 확인: sudo systemctl status raspberry-pi-monitor"
echo ""
echo "⚠️  중요: config.json에서 MQTT 브로커 IP 주소를 실제 서버 IP로 변경하세요!"
