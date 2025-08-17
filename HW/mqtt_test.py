#!/usr/bin/env python3
"""
MQTT 연결 및 통신 테스트 스크립트
Jetson과 라즈베리파이 간 MQTT 통신 확인
"""

import paho.mqtt.client as mqtt
import json
import time
import sys

# 설정
MQTT_BROKER = "192.168.10.3"
MQTT_PORT = 1883
MQTT_USERNAME = "moring"
MQTT_PASSWORD = "kimoring"
VIN = "KNMK5C2HMLP000437"

class MQTTTester:
    def __init__(self):
        self.client = mqtt.Client(client_id="mqtt_tester")
        self.client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        self.client.on_disconnect = self.on_disconnect
        self.connected = False
        self.messages_received = []
        
    def on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            self.connected = True
            print(f"✅ MQTT 브로커 연결 성공! (코드: {rc})")
            
            # 테스트 토픽 구독
            topics = [
                f"car/{VIN}/alert/#",
                f"car/{VIN}/auth/#",
                f"car/{VIN}/status",
                "test/#"
            ]
            
            for topic in topics:
                client.subscribe(topic, qos=1)
                print(f"📥 토픽 구독: {topic}")
                
        else:
            print(f"❌ MQTT 연결 실패! (코드: {rc})")
            print("연결 코드 의미:")
            print("  1: 잘못된 프로토콜 버전")
            print("  2: 잘못된 클라이언트 식별자")
            print("  3: 서버 사용 불가")
            print("  4: 잘못된 사용자명/비밀번호")
            print("  5: 인증되지 않음")
    
    def on_message(self, client, userdata, msg):
        try:
            payload = msg.payload.decode()
            print(f"📨 메시지 수신: {msg.topic}")
            print(f"   내용: {payload}")
            
            # JSON 파싱 시도
            try:
                data = json.loads(payload)
                print(f"   JSON 파싱: {json.dumps(data, indent=2, ensure_ascii=False)}")
            except:
                print(f"   텍스트: {payload}")
                
            self.messages_received.append({
                'topic': msg.topic,
                'payload': payload,
                'timestamp': time.time()
            })
            
        except Exception as e:
            print(f"❌ 메시지 처리 오류: {e}")
    
    def on_disconnect(self, client, userdata, rc):
        self.connected = False
        print(f"🔌 MQTT 연결 해제 (코드: {rc})")
    
    def connect(self):
        try:
            print(f"🔗 MQTT 브로커 연결 시도: {MQTT_BROKER}:{MQTT_PORT}")
            self.client.connect(MQTT_BROKER, MQTT_PORT, 60)
            self.client.loop_start()
            return True
        except Exception as e:
            print(f"❌ 연결 실패: {e}")
            return False
    
    def send_test_message(self, topic, message):
        if not self.connected:
            print("❌ 연결되지 않음")
            return False
            
        try:
            result = self.client.publish(topic, json.dumps(message), qos=1)
            if result.rc == mqtt.MQTT_ERR_SUCCESS:
                print(f"📤 테스트 메시지 발행 성공: {topic}")
                return True
            else:
                print(f"❌ 메시지 발행 실패: {result.rc}")
                return False
        except Exception as e:
            print(f"❌ 메시지 발행 오류: {e}")
            return False
    
    def run_test(self):
        print("🚀 MQTT 통신 테스트 시작")
        print("=" * 50)
        
        # 1. 연결 테스트
        if not self.connect():
            return False
        
        # 연결 대기
        time.sleep(2)
        
        if not self.connected:
            print("❌ 연결 실패")
            return False
        
        # 2. 테스트 메시지 발행
        test_messages = [
            {
                'topic': f'car/{VIN}/alert/sleep',
                'message': {
                    'driver_name': 'TestDriver',
                    'sleep_detected': True,
                    'sleep_count': 1,
                    'sleep_avg': 0.8,
                    'timestamp': time.strftime("%Y-%m-%dT%H:%M:%SZ")
                }
            },
            {
                'topic': f'car/{VIN}/alert/distraction',
                'message': {
                    'driver_name': 'TestDriver',
                    'distraction_detected': True,
                    'timestamp': time.strftime("%Y-%m-%dT%H:%M:%SZ")
                }
            },
            {
                'topic': f'car/{VIN}/alert/unauthorized',
                'message': {
                    'driver_name': 'Unknown',
                    'unauthorized_detected': True,
                    'timestamp': time.strftime("%Y-%m-%dT%H:%M:%SZ")
                }
            }
        ]
        
        print("\n📤 테스트 메시지 발행 중...")
        for test in test_messages:
            self.send_test_message(test['topic'], test['message'])
            time.sleep(1)
        
        # 3. 메시지 수신 대기
        print("\n⏳ 10초간 메시지 수신 대기...")
        time.sleep(10)
        
        # 4. 결과 요약
        print("\n📊 테스트 결과:")
        print(f"   연결 상태: {'✅ 연결됨' if self.connected else '❌ 연결 안됨'}")
        print(f"   수신 메시지: {len(self.messages_received)}개")
        
        if self.messages_received:
            print("\n📨 수신된 메시지들:")
            for i, msg in enumerate(self.messages_received, 1):
                print(f"   {i}. {msg['topic']}: {msg['payload'][:100]}...")
        
        # 5. 정리
        self.client.loop_stop()
        self.client.disconnect()
        
        return len(self.messages_received) > 0

def main():
    print("🔧 MQTT 통신 진단 도구")
    print("=" * 50)
    
    # 설정 확인
    print(f"📡 브로커: {MQTT_BROKER}:{MQTT_PORT}")
    print(f"👤 사용자: {MQTT_USERNAME}")
    print(f"🚗 VIN: {VIN}")
    print()
    
    # 테스트 실행
    tester = MQTTTester()
    success = tester.run_test()
    
    print("\n" + "=" * 50)
    if success:
        print("✅ MQTT 통신 정상!")
    else:
        print("❌ MQTT 통신 문제 발견!")
        print("\n🔧 문제 해결 방법:")
        print("1. 라즈베리파이에서 mosquitto 서비스 실행 확인:")
        print("   sudo systemctl status mosquitto")
        print("2. 라즈베리파이 IP 확인:")
        print("   ip addr show eth0")
        print("3. 방화벽에서 1883 포트 허용:")
        print("   sudo ufw allow 1883")
        print("4. 네트워크 연결 확인:")
        print(f"   ping {MQTT_BROKER}")

if __name__ == "__main__":
    main()
