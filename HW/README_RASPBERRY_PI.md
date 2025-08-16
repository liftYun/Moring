# 라즈베리파이 드라이버 모니터링 시스템

라즈베리파이에서 Jetson과 MQTT 통신하며 센서 제어 및 알림을 전송하는 시스템입니다.

## 📋 기능

- **MQTT 통신**: Jetson과 실시간 통신
- **센서 제어**: CO2, 온습도 센서 측정
- **부저 제어**: 졸음 감지 시 알람
- **서버 알림**: HTTP API를 통한 알림 전송
- **로그 관리**: 상세한 로그 기록

## 🔧 설치

### 1. 자동 설치
```bash
chmod +x install_raspberry_pi.sh
./install_raspberry_pi.sh
```

### 2. 수동 설치
```bash
# 시스템 업데이트
sudo apt update && sudo apt upgrade -y

# 필수 패키지 설치
sudo apt install -y python3 python3-pip python3-venv git mosquitto-clients python3-gpiozero

# Python 가상환경 생성
python3 -m venv venv
source venv/bin/activate

# Python 패키지 설치
pip install paho-mqtt requests

# 센서 라이브러리 설치 (실제 센서에 맞게 수정)
# pip install mh-z19  # CO2 센서
# pip install Adafruit_DHT  # 온습도 센서
```

## ⚙️ 설정

### 설정 파일: `config.json`
```json
{
    "mqtt_broker": "43.203.216.22",
    "mqtt_port": 1883,
    "mqtt_username": "",
    "mqtt_password": "",
    "mqtt_client_id": "raspberry_pi_monitor",
    "car_vin": "KNMK5C2HMLP000437",
    "server_url": "http://localhost:8080",
    "api_endpoint": "/api/v1/notifications/send/general",
    "sensor_interval": 10,
    "buzzer_pin": 18,
    "sleep_alert_type": "DISTRACTION_ALERT",
    "unauthorized_alert_type": "PART_ALERT"
}
```

## 🚀 실행

### 1. 수동 실행
```bash
# 가상환경 활성화
source venv/bin/activate

# 실행
python3 raspberry_pi_simple.py
```

### 2. 서비스로 실행
```bash
# 서비스 시작
sudo systemctl start driver-monitor

# 서비스 상태 확인
sudo systemctl status driver-monitor

# 서비스 중지
sudo systemctl stop driver-monitor
```

## 📡 MQTT 토픽

### 수신 토픽
- `car/{VIN}/alert/sleep`: 졸음 알림 수신

### 발행 토픽
- `car/{VIN}/sensor/data`: 센서 데이터 전송

## 🔌 센서 연결

### CO2 센서 (MH-Z19)
```
VCC → 5V
GND → GND
TX  → GPIO 14 (UART)
RX  → GPIO 15 (UART)
```

### 온습도 센서 (DHT22)
```
VCC → 3.3V
GND → GND
DATA → GPIO 4
```

### 부저
```
VCC → GPIO 18
GND → GND
```

## 📊 센서 데이터 형식

```json
{
    "driver_name": "Owner",
    "co2": 1200,
    "temperature": 25.5,
    "humidity": 65.2,
    "sleep_count": 3,
    "sleep_avg": 0.8,
    "timestamp": "2024-01-01T12:00:00Z"
}
```

## 🔧 센서 코드 수정

실제 센서에 맞게 다음 부분을 수정하세요:

### CO2 센서
```python
def read_co2(self) -> int:
    # 실제 센서 코드로 교체
    # return self.co2_sensor.read_co2()
    return 800  # 임시 값
```

### 온습도 센서
```python
def read_temperature(self) -> float:
    # 실제 센서 코드로 교체
    # return self.temp_humidity_sensor.read_temperature()
    return 25.0  # 임시 값

def read_humidity(self) -> float:
    # 실제 센서 코드로 교체
    # return self.temp_humidity_sensor.read_humidity()
    return 60.0  # 임시 값
```

### 부저
```python
def sound_alarm(self, duration: int = 3):
    # 실제 부저 제어 코드로 교체
    # GPIO.output(self.pin, GPIO.HIGH)
    # time.sleep(duration)
    # GPIO.output(self.pin, GPIO.LOW)
    time.sleep(duration)  # 임시로 대기만
```

## 📝 로그

- **로그 파일**: `raspberry_pi_monitor.log`
- **로그 레벨**: INFO
- **로그 형식**: 시간 - 레벨 - 메시지

### 로그 확인
```bash
# 실시간 로그 확인
tail -f raspberry_pi_monitor.log

# 최근 로그 확인
tail -n 50 raspberry_pi_monitor.log
```

## 🔄 플로우

1. **대기 상태**: MQTT 메시지 대기
2. **졸음 감지**: Jetson에서 졸음 알림 수신
3. **부저 울림**: 즉시 부저 알람
4. **센서 측정**: CO2, 온습도 측정
5. **데이터 전송**: Jetson으로 센서 데이터 전송
6. **서버 알림**: HTTP API로 알림 전송
7. **대기 상태**: 다시 대기

## 🛠️ 문제 해결

### MQTT 연결 실패
```bash
# MQTT 브로커 상태 확인
sudo systemctl status mosquitto

# MQTT 브로커 재시작
sudo systemctl restart mosquitto
```

### 센서 오류
```bash
# 센서 권한 확인
sudo usermod -a -G gpio pi

# 센서 연결 확인
ls /dev/ttyUSB*  # CO2 센서
ls /sys/bus/w1/devices/  # 온습도 센서
```

### 서비스 오류
```bash
# 서비스 로그 확인
sudo journalctl -u driver-monitor -f

# 서비스 재시작
sudo systemctl restart driver-monitor
```

## 📞 지원

문제가 발생하면 로그 파일을 확인하고 개발팀에 문의하세요.
