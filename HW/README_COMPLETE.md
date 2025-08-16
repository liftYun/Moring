# 🚗 완전한 드라이버 모니터링 시스템 가이드

## 📋 시스템 개요

이 시스템은 Jetson과 라즈베리파이를 연동한 완전한 드라이버 모니터링 솔루션입니다.

### 🎯 주요 기능
- **실시간 얼굴 인식 및 운전자 식별**
- **졸음/시선 이탈/휴대폰 사용 감지**
- **자동 승인 시스템 (FCM 연동)**
- **환경 센서 모니터링 (CO2, 온습도)**
- **MQTT 기반 실시간 통신**
- **부저 알림 및 서버 연동**

## 🏗️ 시스템 아키텍처

```
Jetson (얼굴 인식) ←→ MQTT ←→ 라즈베리파이 (센서/부저) ←→ 서버 (FCM/앱)
```

## 📦 설치 및 설정

### 1. Jetson 설정

#### 필수 요구사항
- Jetson Nano/Xavier/Orin
- Python 3.8+
- CUDA 지원
- USB 카메라 또는 CSI 카메라

#### 설치 스크립트 실행
```bash
cd HW
chmod +x install_jetson_optimized.sh
./install_jetson_optimized.sh
```

#### 설정 파일 수정
```bash
nano config_jetson.json
```

주요 설정:
```json
{
  "jetson": {
    "camera_type": "usb",  // "usb" 또는 "csi"
    "enable_gpu_acceleration": true,
    "power_mode": 2
  },
  "approval": {
    "mqtt_broker": "43.203.216.22",
    "mqtt_port": 1883,
    "mqtt_username": "moring",
    "mqtt_password": "kimoring",
    "vin": "KNMK5C2HMLP000437"
  }
}
```

#### 실행
```bash
python3 driver_monitor_jetson.py
```

### 2. 라즈베리파이 설정

#### 필수 요구사항
- Raspberry Pi 4 (권장)
- 센서: MH-Z19 (CO2), DHT22 (온습도)
- 부저 (GPIO 18)

#### 완전 자동 설치
```bash
cd HW
chmod +x install_raspberry_pi_complete.sh
./install_raspberry_pi_complete.sh
```

#### 센서 연결
```
CO2 센서 (MH-Z19):
  VCC → 5V
  GND → GND
  TX → GPIO 14 (UART)
  RX → GPIO 15 (UART)

온습도 센서 (DHT22):
  VCC → 3.3V
  GND → GND
  DATA → GPIO 4

부저:
  VCC → GPIO 18
  GND → GND
```

#### 설정 파일 수정
```bash
nano ~/hw/config.env
```

#### 서비스 시작
```bash
sudo systemctl start raspberry-pi-monitor
sudo systemctl enable raspberry-pi-monitor
```

## 🔧 고급 설정

### MQTT 보안 강화

#### TLS 설정 (선택사항)
```bash
# mosquitto.conf에 추가
listener 8883
certfile /etc/mosquitto/certs/server.crt
keyfile /etc/mosquitto/certs/server.key
```

#### 방화벽 설정
```bash
sudo ufw allow 1883  # MQTT
sudo ufw allow 8883  # MQTT TLS
```

### 로그 관리

#### 로그 로테이션 확인
```bash
# 로그 파일 크기 확인
ls -lh raspberry_pi_unified.log*

# 로그 내용 확인
tail -f raspberry_pi_unified.log
```

#### systemd 로그 확인
```bash
sudo journalctl -u raspberry-pi-monitor -f
```

### 성능 최적화

#### Jetson 성능 튜닝
```bash
# 전력 모드 설정
sudo nvpmodel -m 2  # 최대 성능
sudo jetson_clocks  # 클럭 고정

# GPU 사용 확인
python3 -c "import torch; print(torch.cuda.is_available())"
```

#### 라즈베리파이 최적화
```bash
# CPU 클럭 고정
echo 'arm_freq=2000' | sudo tee -a /boot/config.txt

# GPU 메모리 할당
echo 'gpu_mem=128' | sudo tee -a /boot/config.txt
```

## 🚨 문제 해결

### 일반적인 문제들

#### 1. MQTT 연결 실패
```bash
# 브로커 상태 확인
sudo systemctl status mosquitto

# 연결 테스트
mosquitto_pub -h localhost -p 1883 -u moring -P kimoring -t "test" -m "hello"
```

#### 2. 센서 읽기 실패
```bash
# UART 활성화 확인
sudo raspi-config nonint do_serial 0

# 센서 테스트
python3 -c "from mh_z19 import mh_z19; print(mh_z19.read())"
```

#### 3. 부저 작동 안함
```bash
# GPIO 권한 확인
groups pi

# GPIO 테스트
python3 -c "import RPi.GPIO as GPIO; GPIO.setmode(GPIO.BCM); GPIO.setup(18, GPIO.OUT); GPIO.output(18, GPIO.HIGH)"
```

#### 4. 모델 로드 실패
```bash
# 모델 파일 확인
ls -la models/best.pt

# GPU 사용 확인
nvidia-smi
```

### 로그 분석

#### Jetson 로그
```bash
# 실시간 로그 확인
tail -f driver_monitor_jetson.log

# 오류만 필터링
grep "ERROR" driver_monitor_jetson.log
```

#### 라즈베리파이 로그
```bash
# 서비스 로그
sudo journalctl -u raspberry-pi-monitor -f

# 애플리케이션 로그
tail -f ~/hw/raspberry_pi_unified.log
```

## 📊 모니터링 및 관리

### 시스템 상태 확인

#### Jetson 상태
```bash
# GPU 사용률
nvidia-smi

# 메모리 사용률
free -h

# CPU 사용률
htop
```

#### 라즈베리파이 상태
```bash
# 시스템 정보
vcgencmd get_throttled

# 온도 확인
vcgencmd measure_temp

# 메모리 사용률
free -h
```

### 성능 모니터링

#### 실시간 성능 확인
```bash
# Jetson에서
watch -n 1 nvidia-smi

# 라즈베리파이에서
htop
```

## 🔄 업데이트 및 유지보수

### 정기 업데이트
```bash
# Jetson
sudo apt update && sudo apt upgrade -y

# 라즈베리파이
sudo apt update && sudo apt upgrade -y
```

### 백업 및 복원
```bash
# 설정 파일 백업
cp config_jetson.json config_jetson.json.backup
cp ~/hw/config.env ~/hw/config.env.backup

# 데이터 백업
tar -czf backup_$(date +%Y%m%d).tar.gz data/
```

## 📞 지원 및 문의

### 로그 수집
```bash
# Jetson 로그 수집
tar -czf jetson_logs_$(date +%Y%m%d).tar.gz *.log

# 라즈베리파이 로그 수집
tar -czf rpi_logs_$(date +%Y%m%d).tar.gz ~/hw/*.log
```

### 시스템 정보 수집
```bash
# Jetson 시스템 정보
nvidia-smi > system_info.txt
uname -a >> system_info.txt
python3 --version >> system_info.txt

# 라즈베리파이 시스템 정보
vcgencmd get_throttled > system_info.txt
uname -a >> system_info.txt
python3 --version >> system_info.txt
```

## 🎉 완료!

이제 완전한 드라이버 모니터링 시스템이 준비되었습니다!

### 다음 단계:
1. **센서 연결 확인**
2. **MQTT 브로커 연결 테스트**
3. **실제 운전 테스트**
4. **앱 연동 설정**

모든 기능이 정상 작동하는지 확인하고, 문제가 있으면 로그를 확인하여 해결하세요! 🚀
