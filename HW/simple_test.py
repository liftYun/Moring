#!/usr/bin/env python3
"""
간단한 MQTT 테스트 스크립트
"""

import json
import time
import uuid
import base64
import cv2
import numpy as np
import subprocess
import sys

def create_test_image():
    """테스트용 이미지 생성"""
    image = np.zeros((480, 640, 3), dtype=np.uint8)
    image[:] = (128, 128, 128)
    
    cv2.putText(image, "TEST DRIVER", (200, 240), 
               cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
    cv2.putText(image, "Approval Test", (200, 280), 
               cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)
    
    return image

def test_with_mosquitto_pub():
    """mosquitto_pub을 사용한 테스트"""
    try:
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
        
        # mosquitto_pub 명령어 실행
        topic = "car/KNMK5C2HMLP000437/auth/approval/request"
        message = json.dumps(request_data)
        
        cmd = [
            'mosquitto_pub',
            '-h', '192.168.137.82',
            '-p', '1883',
            '-u', 'moring',
            '-P', 'kimoring',
            '-t', topic,
            '-m', message
        ]
        
        print("MQTT 메시지 전송 중...")
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ 승인 요청 전송 성공!")
            print(f"SessionID: {session_id}")
            print(f"토픽: {topic}")
        else:
            print("❌ 전송 실패:")
            print(result.stderr)
            
    except Exception as e:
        print(f"❌ 오류: {e}")

def test_with_curl():
    """curl을 사용한 테스트 (HTTP를 통해 MQTT)"""
    try:
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
        
        # curl 명령어 실행
        url = "http://192.168.137.82:8080/mqtt/publish"
        headers = "Content-Type: application/json"
        data = json.dumps({
            'topic': 'car/KNMK5C2HMLP000437/auth/approval/request',
            'message': json.dumps(request_data)
        })
        
        cmd = [
            'curl', '-X', 'POST',
            '-H', headers,
            '-d', data,
            url
        ]
        
        print("HTTP를 통한 MQTT 메시지 전송 중...")
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ 승인 요청 전송 성공!")
            print(f"SessionID: {session_id}")
        else:
            print("❌ 전송 실패:")
            print(result.stderr)
            
    except Exception as e:
        print(f"❌ 오류: {e}")

def main():
    """메인 함수"""
    print("🚗 간단한 승인 시스템 테스트")
    print("1. mosquitto_pub로 테스트")
    print("2. curl로 테스트 (HTTP)")
    print("3. 종료")
    
    while True:
        choice = input("\n선택하세요 (1-3): ")
        
        if choice == "1":
            test_with_mosquitto_pub()
        elif choice == "2":
            test_with_curl()
        elif choice == "3":
            print("테스트를 종료합니다.")
            break
        else:
            print("잘못된 선택입니다.")

if __name__ == "__main__":
    main()
