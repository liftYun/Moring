#!/usr/bin/env python3
"""
라즈베리파이 승인 요청 수신기
MQTT로 승인 요청을 받아서 처리하는 스크립트
"""

import json
import logging
import time
import base64
from datetime import datetime
import os

# MQTT 클라이언트
try:
    import paho.mqtt.client as mqtt
    MQTT_AVAILABLE = True
except ImportError:
    MQTT_AVAILABLE = False
    print("MQTT 라이브러리가 설치되지 않았습니다. pip install paho-mqtt")

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('approval_receiver.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)

class ApprovalReceiver:
    """승인 요청 수신 클래스"""
    
    def __init__(self):
        self.mqtt_client = None
        self.mqtt_broker = "192.168.137.82"
        self.mqtt_port = 1883
        self.mqtt_username = "moring"
        self.mqtt_password = "kimoring"
        self.mqtt_client_id = "raspberry_approval_receiver"
        
        # 승인 요청 저장 디렉토리
        self.approval_dir = "./approval_requests"
        os.makedirs(self.approval_dir, exist_ok=True)
        
        if MQTT_AVAILABLE:
            self.initialize_mqtt()
        else:
            logging.error("MQTT를 사용할 수 없습니다")
    
    def initialize_mqtt(self):
        """MQTT 클라이언트 초기화"""
        try:
            self.mqtt_client = mqtt.Client(self.mqtt_client_id)
            self.mqtt_client.username_pw_set(self.mqtt_username, self.mqtt_password)
            
            # 콜백 설정
            self.mqtt_client.on_connect = self.on_mqtt_connect
            self.mqtt_client.on_message = self.on_mqtt_message
            
            # 연결
            self.mqtt_client.connect(self.mqtt_broker, self.mqtt_port)
            
            # 백그라운드 스레드에서 루프 실행
            self.mqtt_client.loop_start()
            
            logging.info("MQTT 클라이언트 초기화 완료")
            
        except Exception as e:
            logging.error(f"MQTT 클라이언트 초기화 실패: {e}")
    
    def on_mqtt_connect(self, client, userdata, flags, rc):
        """MQTT 연결 콜백"""
        if rc == 0:
            logging.info("MQTT 브로커에 연결됨")
            # 모든 차량의 승인 요청 토픽 구독
            request_topic = "car/+/auth/approval/request"
            client.subscribe(request_topic)
            logging.info(f"승인 요청 토픽 구독: {request_topic}")
        else:
            logging.error(f"MQTT 연결 실패: {rc}")
    
    def on_mqtt_message(self, client, userdata, msg):
        """MQTT 메시지 수신 콜백"""
        try:
            # 토픽에서 VIN 추출
            topic_parts = msg.topic.split('/')
            if len(topic_parts) >= 4 and topic_parts[2] == 'auth' and topic_parts[3] == 'approval':
                vin = topic_parts[1]
            else:
                logging.warning(f"알 수 없는 토픽 형식: {msg.topic}")
                return
            
            # 페이로드 파싱
            payload = json.loads(msg.payload.decode())
            session_id = payload.get('sessionId')
            snapshot_url = payload.get('snapshotUrl')
            timestamp = payload.get('timestamp')
            
            logging.info(f"승인 요청 수신 - VIN: {vin}, SessionID: {session_id}")
            
            # 이미지 저장
            self.save_approval_request(vin, session_id, snapshot_url, timestamp)
            
            # 승인 요청 처리 (여기서는 로그만 출력)
            self.process_approval_request(vin, session_id, snapshot_url, timestamp)
            
        except Exception as e:
            logging.error(f"MQTT 메시지 처리 실패: {e}")
    
    def save_approval_request(self, vin: str, session_id: str, snapshot_url: str, timestamp: int):
        """승인 요청 정보 저장"""
        try:
            # 이미지 데이터 추출 (base64)
            if snapshot_url.startswith('data:image/jpeg;base64,'):
                image_data = snapshot_url.split(',')[1]
                image_bytes = base64.b64decode(image_data)
                
                # 이미지 파일 저장
                timestamp_str = datetime.fromtimestamp(timestamp).strftime('%Y%m%d_%H%M%S')
                image_filename = f"{vin}_{session_id}_{timestamp_str}.jpg"
                image_path = os.path.join(self.approval_dir, image_filename)
                
                with open(image_path, 'wb') as f:
                    f.write(image_bytes)
                
                logging.info(f"이미지 저장 완료: {image_path}")
                
                # 요청 정보 JSON 저장
                request_info = {
                    'vin': vin,
                    'session_id': session_id,
                    'timestamp': timestamp,
                    'image_path': image_path,
                    'received_time': datetime.now().isoformat()
                }
                
                info_filename = f"{vin}_{session_id}_{timestamp_str}.json"
                info_path = os.path.join(self.approval_dir, info_filename)
                
                with open(info_path, 'w', encoding='utf-8') as f:
                    json.dump(request_info, f, indent=2, ensure_ascii=False)
                
                logging.info(f"요청 정보 저장 완료: {info_path}")
                
            else:
                logging.warning(f"지원하지 않는 이미지 형식: {snapshot_url[:50]}...")
                
        except Exception as e:
            logging.error(f"승인 요청 저장 실패: {e}")
    
    def process_approval_request(self, vin: str, session_id: str, snapshot_url: str, timestamp: int):
        """승인 요청 처리 (현재는 로그만 출력)"""
        try:
            logging.info("=" * 60)
            logging.info("🚨 새로운 승인 요청!")
            logging.info(f"차량 VIN: {vin}")
            logging.info(f"세션 ID: {session_id}")
            logging.info(f"요청 시간: {datetime.fromtimestamp(timestamp)}")
            logging.info("=" * 60)
            
            # 여기에 실제 승인 처리 로직이 들어갈 예정
            # 예: FCM 푸시 알림, SMS 발송, 부저 울리기 등
            
            # 임시로 승인 거부 응답 (테스트용)
            self.send_approval_response(vin, session_id, "DENY")
            
        except Exception as e:
            logging.error(f"승인 요청 처리 실패: {e}")
    
    def send_approval_response(self, vin: str, session_id: str, decision: str):
        """승인 응답 발송"""
        try:
            response_data = {
                'sessionId': session_id,
                'decision': decision
            }
            
            response_topic = f"car/{vin}/auth/approval/response"
            self.mqtt_client.publish(response_topic, json.dumps(response_data))
            
            logging.info(f"승인 응답 발송: {decision} (SessionID: {session_id})")
            
        except Exception as e:
            logging.error(f"승인 응답 발송 실패: {e}")
    
    def cleanup(self):
        """정리"""
        if self.mqtt_client:
            self.mqtt_client.loop_stop()
            self.mqtt_client.disconnect()
            logging.info("MQTT 연결 종료")

def main():
    """메인 함수"""
    print("🚗 라즈베리파이 승인 요청 수신기 시작")
    print("MQTT 브로커에 연결하여 승인 요청을 대기합니다...")
    
    receiver = ApprovalReceiver()
    
    try:
        # 무한 대기
        while True:
            time.sleep(1)
            
    except KeyboardInterrupt:
        print("\n사용자에 의해 중단되었습니다.")
    except Exception as e:
        logging.error(f"실행 중 오류 발생: {e}")
    finally:
        receiver.cleanup()
        print("수신기가 종료되었습니다.")

if __name__ == "__main__":
    main()
