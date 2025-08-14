#!/usr/bin/env python3
"""
승인 시스템 테스트 스크립트
젯슨과 라즈베리파이 간의 승인 시스템을 테스트합니다.
"""

import json
import time
import uuid
import base64
import cv2
import numpy as np

# MQTT 클라이언트
try:
    import paho.mqtt.client as mqtt
    MQTT_AVAILABLE = True
except ImportError:
    MQTT_AVAILABLE = False
    print("MQTT 라이브러리가 설치되지 않았습니다. pip install paho-mqtt")

def create_test_image():
    """테스트용 이미지 생성"""
    # 640x480 크기의 테스트 이미지 생성
    image = np.zeros((480, 640, 3), dtype=np.uint8)
    
    # 배경을 회색으로
    image[:] = (128, 128, 128)
    
    # 텍스트 추가
    cv2.putText(image, "TEST DRIVER", (200, 240), 
               cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
    cv2.putText(image, "Approval Test", (200, 280), 
               cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)
    
    return image

def test_approval_request():
    """승인 요청 테스트"""
    if not MQTT_AVAILABLE:
        print("MQTT를 사용할 수 없습니다")
        return
    
    # MQTT 클라이언트 설정
    client = mqtt.Client("test_approval_sender")
    client.username_pw_set("moring", "kimoring")
    
    try:
        # 연결
        client.connect("192.168.137.82", 1883)
        client.loop_start()
        
        print("MQTT 브로커에 연결됨")
        
        # 테스트 이미지 생성
        test_image = create_test_image()
        
        # 이미지 인코딩
        _, buffer = cv2.imencode('.jpg', test_image)
        image_base64 = base64.b64encode(buffer).decode('utf-8')
        
        # 승인 요청 메시지
        session_id = str(uuid.uuid4())
        request_data = {
            'sessionId': session_id,
            'snapshotUrl': f"data:image/jpeg;base64,{image_base64}",
            'vin': 'KNMK5C2HMLP000437',
            'timestamp': int(time.time())
        }
        
        # 요청 발송
        request_topic = "car/KNMK5C2HMLP000437/auth/approval/request"
        client.publish(request_topic, json.dumps(request_data))
        
        print(f"승인 요청 발송 완료")
        print(f"SessionID: {session_id}")
        print(f"토픽: {request_topic}")
        
        # 응답 대기
        print("응답을 기다리는 중... (10초)")
        time.sleep(10)
        
    except Exception as e:
        print(f"테스트 실패: {e}")
    finally:
        client.loop_stop()
        client.disconnect()

def test_approval_response():
    """승인 응답 테스트"""
    if not MQTT_AVAILABLE:
        print("MQTT를 사용할 수 없습니다")
        return
    
    # MQTT 클라이언트 설정
    client = mqtt.Client("test_approval_responder")
    client.username_pw_set("moring", "kimoring")
    
    try:
        # 연결
        client.connect("192.168.137.82", 1883)
        client.loop_start()
        
        print("MQTT 브로커에 연결됨")
        
        # 테스트 세션 ID
        session_id = input("응답할 SessionID를 입력하세요: ")
        decision = input("결정을 입력하세요 (APPROVE/DENY): ").upper()
        
        if decision not in ["APPROVE", "DENY"]:
            print("잘못된 결정입니다. APPROVE 또는 DENY를 입력하세요.")
            return
        
        # 응답 발송
        response_data = {
            'sessionId': session_id,
            'decision': decision
        }
        
        response_topic = "car/KNMK5C2HMLP000437/auth/approval/response"
        client.publish(response_topic, json.dumps(response_data))
        
        print(f"승인 응답 발송 완료")
        print(f"SessionID: {session_id}")
        print(f"결정: {decision}")
        print(f"토픽: {response_topic}")
        
    except Exception as e:
        print(f"테스트 실패: {e}")
    finally:
        client.loop_stop()
        client.disconnect()

def main():
    """메인 함수"""
    print("🚗 승인 시스템 테스트")
    print("1. 승인 요청 테스트")
    print("2. 승인 응답 테스트")
    print("3. 종료")
    
    while True:
        choice = input("\n선택하세요 (1-3): ")
        
        if choice == "1":
            test_approval_request()
        elif choice == "2":
            test_approval_response()
        elif choice == "3":
            print("테스트를 종료합니다.")
            break
        else:
            print("잘못된 선택입니다.")

if __name__ == "__main__":
    main()
