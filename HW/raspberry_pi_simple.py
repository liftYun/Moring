#!/usr/bin/env python3
"""
라즈베리파이 간단 실행 파일
MQTT 통신 + 센서 제어 + 승인 시스템
"""

import json
import time
import logging
import requests
import os
from datetime import datetime
import paho.mqtt.client as mqtt
import threading

# 설정 파일 로드
def load_config():
    try:
        with open('config.json', 'r', encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        print("config.json 파일을 찾을 수 없습니다. 기본 설정을 사용합니다.")
        return {
            "mqtt": {
                "broker": "192.168.10.3",
                "port": 1883,
                "username": "moring",
                "password": "kimoring",
                "client_id_raspberry": "raspberry_pi_monitor"
            },
            "vehicle": {
                "vin": "KNMK5C2HMLP000437"
            },
            "server": {
                "base_url": "https://i13e101.p.ssafy.io",
                "approval_endpoint": "/api/v1/notifications/send/approval"
            },
            "notifications": {
                "mattermost_webhook": "https://meeting.ssafy.com/hooks/4emuoribrfn89dreyefdt9etwe",
                "fcm_timeout": 10,
                "approval_timeout": 300
            },
            "sensors": {
                "dht11_pin": 4,
                "mhz19b_port": "/dev/ttyAMA0",
                "buzzer_pin": 18,
                "read_interval": 10
            }
        }

# 설정 로드
config = load_config()

# 설정값 추출
MQTT_BROKER = config["mqtt"]["broker"]
MQTT_PORT = config["mqtt"]["port"]
MQTT_USERNAME = config["mqtt"]["username"]
MQTT_PASSWORD = config["mqtt"]["password"]
MQTT_CLIENT_ID = config["mqtt"]["client_id_raspberry"]
CAR_VIN = config["vehicle"]["vin"]
SERVER_URL = config["server"]["base_url"]
APPROVAL_ENDPOINT = config["server"]["approval_endpoint"]
MATTERMOST_WEBHOOK_URL = config["notifications"]["mattermost_webhook"]
FCM_TIMEOUT = config["notifications"]["fcm_timeout"]
APPROVAL_TIMEOUT = config["notifications"]["approval_timeout"]
BUZZER_PIN = config["sensors"]["buzzer_pin"]
DHT11_PIN = config["sensors"]["dht11_pin"]
MHZ19B_PORT = config["sensors"]["mhz19b_port"]

# 센서 클래스들
class BuzzerController:
    def __init__(self, pin=None):
        self.pin = pin or BUZZER_PIN
        try:
            import RPi.GPIO as GPIO
            GPIO.setmode(GPIO.BCM)
            GPIO.setup(self.pin, GPIO.OUT)
            self.gpio = GPIO
            logger.info(f"부저 초기화 완료 (GPIO {self.pin})")
        except ImportError:
            logger.warning("RPi.GPIO 없음 - 부저 사용 불가")
            self.gpio = None
    
    def sound_alarm(self, duration=3):
        if self.gpio:
            logger.info(f"부저 울림: {duration}초")
            self.gpio.output(self.pin, self.gpio.HIGH)
            time.sleep(duration)
            self.gpio.output(self.pin, self.gpio.LOW)
        else:
            logger.info(f"부저 울림 (시뮬레이션): {duration}초")

class DHT11Controller:
    def __init__(self, pin=None):
        self.pin = pin or DHT11_PIN
        try:
            import Adafruit_DHT
            self.dht = Adafruit_DHT
            logger.info(f"DHT11 센서 초기화 완료 (GPIO {self.pin})")
        except ImportError:
            logger.warning("Adafruit_DHT 없음 - 온습도 센서 사용 불가")
            self.dht = None
    
    def read_sensor(self):
        if self.dht:
            try:
                humidity, temperature = self.dht.read_retry(self.dht.DHT11, self.pin)
                if humidity is not None and temperature is not None:
                    return {"tempC": round(temperature, 1), "hum": round(humidity, 1)}
            except:
                pass
        return {"tempC": 25.0, "hum": 60.0}  # 기본값

class MHZ19BController:
    def __init__(self, port=None):
        self.port = port or MHZ19B_PORT
        try:
            import serial
            self.serial = serial
            self.ser = serial.Serial(self.port, baudrate=9600, timeout=1)
            logger.info(f"MH-Z19B 센서 초기화 완료 ({self.port})")
        except ImportError:
            logger.warning("pyserial 없음 - CO2 센서 사용 불가")
            self.ser = None
        except:
            logger.warning(f"CO2 센서 연결 실패 ({self.port})")
            self.ser = None
    
    def read_co2(self):
        if self.ser:
            try:
                self.ser.write(b'\xFF\x01\x86\x00\x00\x00\x00\x00\x79')
                time.sleep(0.1)
                resp = self.ser.read(9)
                if len(resp) == 9:
                    checksum = 0xFF - (sum(resp[1:8]) % 256) + 1
                    if resp[0] == 0xFF and resp[1] == 0x86 and resp[8] == (checksum & 0xFF):
                        return resp[2] * 256 + resp[3]
            except:
                pass
        return 800  # 기본값

class MQTTClient:
    def __init__(self):
        self.client = mqtt.Client(client_id=MQTT_CLIENT_ID)
        self.client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        self.connected = False
        
        # 컨트롤러들
        self.buzzer = BuzzerController()
        self.dht11 = DHT11Controller()
        self.mhz19b = MHZ19BController()
        
        # 승인 요청 저장
        self.approval_requests = {}
    
    def connect(self):
        try:
            self.client.connect(MQTT_BROKER, MQTT_PORT, 60)
            self.client.loop_start()
            logger.info("MQTT 브로커에 연결됨")
        except Exception as e:
            logger.error(f"MQTT 연결 실패: {e}")
    
    def on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            self.connected = True
            logger.info("MQTT 연결 성공")
            
            # 온라인 상태 발행
            online_msg = json.dumps({
                "status": "online",
                "timestamp": datetime.now().isoformat()
            })
            client.publish(f"car/{CAR_VIN}/status", online_msg, qos=1, retain=True)
            
            # 토픽 구독
            topics = [
                (f"car/{CAR_VIN}/alert/#", 1),
                (f"car/{CAR_VIN}/auth/#", 1)
            ]
            for topic, qos in topics:
                client.subscribe(topic, qos)
                logger.info(f"토픽 구독: {topic}")
        else:
            logger.error(f"MQTT 연결 실패: {rc}")
    
    def on_message(self, client, userdata, msg):
        try:
            topic = msg.topic
            data = json.loads(msg.payload.decode())
            logger.info(f"메시지 수신: {topic}")
            
            if "alert/sleep" in topic:
                self.handle_sleep_alert(data)
            elif "alert/distraction" in topic:
                self.handle_distraction_alert(data)
            elif "alert/unauthorized" in topic:
                self.handle_unauthorized_alert(data)
            elif "auth/approval/request" in topic:
                self.handle_approval_request(data)
                
        except Exception as e:
            logger.error(f"메시지 처리 실패: {e}")
    
    def handle_sleep_alert(self, data):
        logger.info("졸음 감지!")
        self.buzzer.sound_alarm(3)
        self.send_alert_to_server("SLEEP_ALERT", data)
    
    def handle_distraction_alert(self, data):
        logger.info("시선 이탈 감지!")
        self.buzzer.sound_alarm(1)
        self.send_alert_to_server("DISTRACTION_ALERT", data)
    
    def handle_unauthorized_alert(self, data):
        logger.info("비인가 사용자 감지!")
        self.buzzer.sound_alarm(5)
        self.send_alert_to_server("UNAUTHORIZED_USER_ALERT", data)
    
    def handle_approval_request(self, data):
        session_id = data.get('sessionId')
        snapshot_url = data.get('snapshotUrl')
        timestamp = data.get('timestamp')
        
        logger.info("=" * 50)
        logger.info("🚨 새로운 승인 요청!")
        logger.info(f"세션 ID: {session_id}")
        logger.info("=" * 50)
        
        # 부저 울리기
        self.buzzer.sound_alarm(2)
        
        # FCM 알림 전송
        self.send_fcm_approval_request(session_id, snapshot_url, timestamp)
        
        # 타임아웃 설정 (5분)
        self.start_approval_timeout(session_id)
    
    def send_fcm_approval_request(self, session_id, snapshot_url, timestamp):
        try:
            url = f"{SERVER_URL}{APPROVAL_ENDPOINT}"
            payload = {
                "vin": CAR_VIN,
                "session_id": session_id,
                "snapshot_url": snapshot_url,
                "timestamp": timestamp,
                "notification_type": "DRIVER_APPROVAL_REQUEST"
            }

            logger.info(f"[SEND APPROVAL] URL: {url}")
            logger.info(f"[SEND APPROVAL] PAYLOAD: {json.dumps(payload, indent=2)}")

            response = requests.post(url, json=payload, timeout=FCM_TIMEOUT)
            if response.status_code == 200:
                logger.info(f"FCM 승인 요청 전송 성공: {session_id}")
            else:
                logger.warning(f"FCM 전송 실패: {response.status_code}")
        except Exception as e:
            logger.warning(f"FCM 전송 실패: {e}")
    
    def start_approval_timeout(self, session_id):
        def timeout_handler():
            time.sleep(APPROVAL_TIMEOUT)  # 5분
            logger.warning(f"승인 요청 타임아웃: {session_id}")
            self.send_approval_response(session_id, "DENY")
        
        thread = threading.Thread(target=timeout_handler)
        thread.daemon = True
        thread.start()
    
    def send_approval_response(self, session_id, decision):
        try:
            response_data = {
                'sessionId': session_id,
                'result': decision
            }
            
            topic = f"car/{CAR_VIN}/auth/approval/response"
            self.client.publish(topic, json.dumps(response_data))
            logger.info(f"승인 응답 발송: {decision}")
        except Exception as e:
            logger.error(f"승인 응답 발송 실패: {e}")
    
    def send_alert_to_server(self, alert_type, data):
        try:
            url = f"{SERVER_URL}/api/v1/notifications/send/general/{CAR_VIN}"
            params = {"notificationDetailType": alert_type}
            
            # 센서 데이터 추가
            sensor_data = {
                "co2": self.mhz19b.read_co2(),
                "temperature": self.dht11.read_sensor()["tempC"],
                "humidity": self.dht11.read_sensor()["hum"],
                "timestamp": datetime.now().isoformat()
            }
            
            payload = {
                "driver_name": data.get("driver_name", "Unknown"),
                "sensor_data": sensor_data,
                "timestamp": datetime.now().isoformat()
            }

            logger.info(f"[SEND ALERT] URL: {url}")
            logger.info(f"[SEND ALERT] PARAMS: {params}")
            logger.info(f"[SEND ALERT] PAYLOAD: {json.dumps(payload, indent=2)}")
            
            response = requests.post(url, params=params, json=payload, timeout=10)
            if response.status_code == 200:
                logger.info(f"{alert_type} 알림 전송 성공")
            else:
                logger.error(f"{alert_type} 알림 전송 실패: {response.status_code}")
        
            self.send_mattermost_alert(alert_type, payload)
        
        except Exception as e:
            logger.error(f"{alert_type} 알림 전송 실패: {e}")
    
    def run(self):
        logger.info("🚗 라즈베리파이 모니터링 시스템 시작")
        self.connect()
        
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            logger.info("사용자에 의해 중단됨")
        finally:
            self.client.loop_stop()
            self.client.disconnect()
            logger.info("시스템 종료")

def send_mattermost_alert(self, alert_type, payload):
    try:
        if not MATTERMOST_WEBHOOK_URL:
            logger.warning("Mattermost Webhook URL이 설정되지 않았습니다.")
            return

        text = (
            f"🚨 *{alert_type.replace('_', ' ')}* 발생!\n"
            f"👤 운전자: {payload.get('driver_name')}\n"
            f"🌡️ 온도: {payload['sensor_data']['temperature']}°C\n"
            f"💧 습도: {payload['sensor_data']['humidity']}%\n"
            f"🫁 CO2: {payload['sensor_data']['co2']} ppm\n"
            f"🕒 시간: {payload['sensor_data']['timestamp']}"
        )

        message = {"text": text}
        response = requests.post(MATTERMOST_WEBHOOK_URL, json=message, timeout=5)

        if response.status_code == 200:
            logger.info("✅ Mattermost 알림 전송 성공")
        else:
            logger.warning(f"❌ Mattermost 전송 실패: {response.status_code}")

    except Exception as e:
        logger.error(f"Mattermost 알림 전송 중 오류: {e}")

def main():
    mqtt_client = MQTTClient()
    mqtt_client.run()

if __name__ == "__main__":
    main()
