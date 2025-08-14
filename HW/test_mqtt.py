#!/usr/bin/env python3
"""
MQTT 연결 테스트 스크립트
Jetson에서 MQTT 브로커로 메시지를 보내고 받는 테스트
"""

import paho.mqtt.client as mqtt
import json
import time
import sys

# MQTT 설정 (USB 테더링)
MQTT_BROKER = "192.168.42.1"  # 라즈베리파이 USB 테더링 IP
MQTT_PORT = 1883
MQTT_USER = "moring"
MQTT_PASS = "kimoring"

# 테스트 데이터
TEST_ALERTS = [
    {
        "type": "drowsiness",
        "data": {
            "ear": 0.15,
            "pitch": 12.5,
            "eye_threshold": 0.25,
            "pitch_threshold": 15.0
        }
    },
    {
        "type": "distraction",
        "data": {
            "yaw": 25.0,
            "roll": 18.0,
            "yaw_threshold": 20.0,
            "roll_threshold": 15.0
        }
    },
    {
        "type": "phone_usage",
        "data": {
            "detected_objects": 1,
            "confidence": 0.85
        }
    }
]

def on_connect(client, userdata, flags, rc):
    """MQTT 연결 성공 시 호출"""
    if rc == 0:
        print(f"✅ MQTT 브로커에 연결되었습니다! (코드: {rc})")
        # 테스트 토픽 구독
        client.subscribe("car/+/alert")
        client.subscribe("car/+/status")
        print("📡 테스트 토픽 구독 완료")
    else:
        print(f"❌ MQTT 연결 실패 (코드: {rc})")

def on_disconnect(client, userdata, rc):
    """MQTT 연결 해제 시 호출"""
    print("🔌 MQTT 연결이 해제되었습니다.")

def on_message(client, userdata, msg):
    """메시지 수신 시 호출"""
    try:
        payload = msg.payload.decode('utf-8')
        data = json.loads(payload)
        print(f"📨 메시지 수신 - 토픽: {msg.topic}")
        print(f"   내용: {json.dumps(data, indent=2, ensure_ascii=False)}")
    except Exception as e:
        print(f"❌ 메시지 파싱 오류: {e}")

def publish_test_alert(client, alert_data, user_id="DriverA"):
    """테스트 알림 발행"""
    topic = f"car/{user_id}/alert"
    message = {
        "type": alert_data["type"],
        "timestamp": time.time(),
        "data": alert_data["data"]
    }
    
    payload = json.dumps(message, ensure_ascii=False)
    client.publish(topic, payload, qos=1)
    
    print(f"📤 테스트 알림 발행 - 토픽: {topic}")
    print(f"   내용: {json.dumps(message, indent=2, ensure_ascii=False)}")

def main():
    """메인 함수"""
    print("🚀 MQTT 연결 테스트 시작")
    print(f"   브로커: {MQTT_BROKER}:{MQTT_PORT}")
    print(f"   사용자: {MQTT_USER}")
    
    # MQTT 클라이언트 생성 (자동 CLIENT_ID 생성)
    client = mqtt.Client()
    client.username_pw_set(MQTT_USER, MQTT_PASS)
    
    # 콜백 설정
    client.on_connect = on_connect
    client.on_disconnect = on_disconnect
    client.on_message = on_message
    
    try:
        # 브로커에 연결
        print("🔗 MQTT 브로커에 연결 중...")
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        client.loop_start()
        
        # 연결 대기
        time.sleep(2)
        
        if not client.is_connected():
            print("❌ MQTT 브로커 연결에 실패했습니다.")
            return
        
        # 테스트 알림 발행
        print("\n📤 테스트 알림 발행 중...")
        for i, alert in enumerate(TEST_ALERTS, 1):
            print(f"\n--- 테스트 {i} ---")
            publish_test_alert(client, alert)
            time.sleep(2)  # 2초 대기
        
        # 메시지 수신 대기
        print("\n📨 메시지 수신 대기 중... (10초)")
        time.sleep(10)
        
    except Exception as e:
        print(f"❌ 오류 발생: {e}")
    
    finally:
        # 연결 정리
        print("\n🔌 연결 정리 중...")
        client.loop_stop()
        client.disconnect()
        print("✅ 테스트 완료")

if __name__ == "__main__":
    main()
