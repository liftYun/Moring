import cv2
import mediapipe as mp
import numpy as np
from scipy.spatial import distance as dist
import time
import json
import os
import argparse
import subprocess
import sys
import paho.mqtt.client as mqtt
from datetime import datetime
import threading

# 라이브러리 자동 설치 및 확인
def check_and_install_libraries():
    """필요한 라이브러리들을 확인하고 설치합니다."""
    required_libraries = {
        'face_recognition': 'face-recognition',
        'ultralytics': 'ultralytics',
        'paho-mqtt': 'paho-mqtt'
    }
    
    missing_libraries = []
    
    for lib_name, pip_name in required_libraries.items():
        try:
            __import__(lib_name.replace('-', '_'))
            print(f"[INFO] {lib_name} 라이브러리가 설치되어 있습니다.")
        except ImportError:
            print(f"[WARNING] {lib_name} 라이브러리가 설치되어 있지 않습니다.")
            missing_libraries.append(pip_name)
    
    if missing_libraries:
        print("[INFO] 누락된 라이브러리를 설치합니다...")
        for lib in missing_libraries:
            try:
                subprocess.check_call([sys.executable, "-m", "pip", "install", lib])
                print(f"[INFO] {lib} 설치 완료")
            except subprocess.CalledProcessError:
                print(f"[ERROR] {lib} 설치 실패")
                return False
    
    return True

# 라이브러리 확인 및 설치
if not check_and_install_libraries():
    print("[ERROR] 필요한 라이브러리 설치에 실패했습니다.")
    sys.exit(1)

# 이제 라이브러리들을 import
import face_recognition
from ultralytics import YOLO

# ---------------------------
# MQTT 설정
# ---------------------------
MQTT_BROKER = "192.168.10.3"
MQTT_PORT = 1883
MQTT_USERNAME = "moring"
MQTT_PASSWORD = "kimoring"
MQTT_TOPIC_PREFIX = "car"

class MqttManager:
    def __init__(self, vin_number):
        self.vin_number = vin_number
        self.client = mqtt.Client()
        self.client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
        self.client.on_connect = self.on_connect
        self.client.on_disconnect = self.on_disconnect
        self.client.on_publish = self.on_publish
        self.connected = False
        
    def on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            print(f"[MQTT] 브로커에 연결되었습니다. (코드: {rc})")
            self.connected = True
        else:
            print(f"[MQTT] 연결 실패. 코드: {rc}")
            self.connected = False
    
    def on_disconnect(self, client, userdata, rc):
        print(f"[MQTT] 브로커와 연결이 끊어졌습니다. 코드: {rc}")
        self.connected = False
    
    def on_publish(self, client, userdata, mid):
        print(f"[MQTT] 메시지 발행 완료. 메시지 ID: {mid}")
    
    def connect(self):
        try:
            self.client.connect(MQTT_BROKER, MQTT_PORT, 60)
            self.client.loop_start()
            return True
        except Exception as e:
            print(f"[MQTT] 연결 오류: {e}")
            return False
    
    def disconnect(self):
        self.client.loop_stop()
        self.client.disconnect()
    
    def publish_alert(self, alert_type, data):
        if not self.connected:
            print("[MQTT] 브로커에 연결되지 않았습니다.")
            return False
        
        topic = f"{MQTT_TOPIC_PREFIX}/{self.vin_number}/alert"
        message = {
            "type": alert_type,
            "data": data,
            "timestamp": datetime.now().isoformat(),
            "vin_number": self.vin_number
        }
        
        try:
            result = self.client.publish(topic, json.dumps(message))
            if result.rc == mqtt.MQTT_ERR_SUCCESS:
                print(f"[MQTT] 알림 발행: {alert_type} - {data}")
                return True
            else:
                print(f"[MQTT] 발행 실패. 코드: {result.rc}")
                return False
        except Exception as e:
            print(f"[MQTT] 발행 오류: {e}")
            return False

# ---------------------------
# 실행 인자 설정
# ---------------------------
parser = argparse.ArgumentParser()
parser.add_argument("--vin_number", type=str, default="KMHXX00XXXX000000")
parser.add_argument("--measure_time", type=int, default=300)  # baseline 측정 시간(초)
parser.add_argument("--eye_ar_ratio", type=float, default=0.6)  # 더 관대하게 (0.8 → 0.6)
parser.add_argument("--pitch_ratio", type=float, default=2.0)   # 더 관대하게 (1.5 → 2.0)
parser.add_argument("--yaw_ratio", type=float, default=3.0)     # 더 관대하게 (2.0 → 3.0)
parser.add_argument("--roll_ratio", type=float, default=2.0)    # 더 관대하게 (1.2 → 2.0)
parser.add_argument("--face_threshold", type=float, default=0.45)  # 얼굴 인식 임계값 (0.45 = 더 엄격)
parser.add_argument("--test_mode", action="store_true")
parser.add_argument("--mqtt_enabled", action="store_true", default=True)
args = parser.parse_args()

# ---------------------------
# 파일 경로 설정
# ---------------------------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(BASE_DIR, "models")
DATA_DIR = os.path.join(BASE_DIR, "data")

YOLO_MODEL_PATH = os.path.join(MODEL_DIR, "best.pt")
FACE_DB_PATH = os.path.join(DATA_DIR, "registered_faces.json")
BASELINE_FILE = os.path.join(DATA_DIR, "baseline.json")

os.makedirs(MODEL_DIR, exist_ok=True)
os.makedirs(DATA_DIR, exist_ok=True)

# YOLO 모델 로드
if not os.path.exists(YOLO_MODEL_PATH):
    raise FileNotFoundError(f"YOLO 모델 파일을 찾을 수 없습니다: {YOLO_MODEL_PATH}")

model = YOLO(YOLO_MODEL_PATH)

# ---------------------------
# MediaPipe 설정
# ---------------------------
mp_face_mesh = mp.solutions.face_mesh
mp_drawing = mp.solutions.drawing_utils
mp_drawing_styles = mp.solutions.drawing_styles

# ---------------------------
# Ratio 값 세팅
# ---------------------------
RATIOS = {
    "EYE_AR_RATIO": args.eye_ar_ratio,
    "PITCH_RATIO": args.pitch_ratio,
    "YAW_RATIO": args.yaw_ratio,
    "ROLL_RATIO": args.roll_ratio
}

# ---------------------------
# MQTT 매니저 초기화
# ---------------------------
mqtt_manager = None
if args.mqtt_enabled:
    mqtt_manager = MqttManager(args.vin_number)
    if not mqtt_manager.connect():
        print("[WARNING] MQTT 연결에 실패했습니다. MQTT 없이 실행됩니다.")
        mqtt_manager = None

# ---------------------------
# 얼굴 랜드마크 인덱스
# ---------------------------
FACIAL_LANDMARKS_IDXS = {
    "left_eye": [362, 385, 387, 263, 373, 380],
    "right_eye": [33, 160, 158, 133, 153, 144],
    "nose": [1],
    "mouth": [61, 84, 17, 314, 405, 320, 307]
}

# ---------------------------
# 유틸리티 함수들
# ---------------------------
def eye_aspect_ratio(eye):
    """눈의 종횡비를 계산합니다."""
    A = dist.euclidean(eye[1], eye[5])
    B = dist.euclidean(eye[2], eye[4])
    C = dist.euclidean(eye[0], eye[3])
    ear = (A + B) / (2.0 * C)
    return ear

def calculate_head_pose(face_landmarks, image_shape):
    """머리 포즈를 계산합니다."""
    if face_landmarks is None:
        return None
    
    # 3D 모델 포인트
    model_points = np.array([
        (0.0, 0.0, 0.0),             # 코 끝
        (0.0, -330.0, -65.0),        # 턱
        (-225.0, 170.0, -135.0),     # 왼쪽 눈
        (225.0, 170.0, -135.0),      # 오른쪽 눈
        (-150.0, -150.0, -125.0),    # 왼쪽 입
        (150.0, -150.0, -125.0)      # 오른쪽 입
    ])
    
    # 2D 이미지 포인트
    image_points = np.array([
        face_landmarks.landmark[1],   # 코 끝
        face_landmarks.landmark[152], # 턱
        face_landmarks.landmark[226], # 왼쪽 눈
        face_landmarks.landmark[446], # 오른쪽 눈
        face_landmarks.landmark[57],  # 왼쪽 입
        face_landmarks.landmark[287]  # 오른쪽 입
    ], dtype="double")
    
    # 픽셀 좌표로 변환
    image_points[:, 0] *= image_shape[1]
    image_points[:, 1] *= image_shape[0]
    
    # 카메라 매트릭스 (가정)
    focal_length = image_shape[1]
    center = (image_shape[1]/2, image_shape[0]/2)
    camera_matrix = np.array(
        [[focal_length, 0, center[0]],
         [0, focal_length, center[1]],
         [0, 0, 1]], dtype="double"
    )
    
    dist_coeffs = np.zeros((4,1))
    
    # PnP 해결
    (success, rotation_vec, translation_vec) = cv2.solvePnP(
        model_points, image_points, camera_matrix, dist_coeffs, 
        flags=cv2.SOLVEPNP_ITERATIVE
    )
    
    if success:
        # 회전 벡터를 각도로 변환
        rotation_mat, _ = cv2.Rodrigues(rotation_vec)
        pose_mat = cv2.hconcat((rotation_mat, translation_vec))
        _, _, _, _, _, _, euler_angles = cv2.decomposeProjectionMatrix(pose_mat)
        
        return {
            'pitch': euler_angles[0][0],
            'yaw': euler_angles[1][0],
            'roll': euler_angles[2][0]
        }
    
    return None

def load_baseline():
    """기준값을 로드합니다."""
    if os.path.exists(BASELINE_FILE):
        with open(BASELINE_FILE, 'r') as f:
            return json.load(f)
    return None

def save_baseline(baseline_data):
    """기준값을 저장합니다."""
    with open(BASELINE_FILE, 'w') as f:
        json.dump(baseline_data, f, indent=2)

def measure_baseline(cap, measure_time=300):
    """기준값을 측정합니다."""
    print(f"[INFO] {measure_time}초 동안 기준값을 측정합니다...")
    
    with mp_face_mesh.FaceMesh(
        max_num_faces=1,
        refine_landmarks=True,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5
    ) as face_mesh:
        
        start_time = time.time()
        ear_values = []
        head_poses = []
        
        while time.time() - start_time < measure_time:
            ret, frame = cap.read()
            if not ret:
                continue
            
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            results = face_mesh.process(frame_rgb)
            
            if results.multi_face_landmarks:
                face_landmarks = results.multi_face_landmarks[0]
                
                # 눈 종횡비 계산
                left_eye = []
                right_eye = []
                
                for idx in FACIAL_LANDMARKS_IDXS["left_eye"]:
                    point = face_landmarks.landmark[idx]
                    left_eye.append([point.x * frame.shape[1], point.y * frame.shape[0]])
                
                for idx in FACIAL_LANDMARKS_IDXS["right_eye"]:
                    point = face_landmarks.landmark[idx]
                    right_eye.append([point.x * frame.shape[1], point.y * frame.shape[0]])
                
                left_ear = eye_aspect_ratio(np.array(left_eye))
                right_ear = eye_aspect_ratio(np.array(right_eye))
                avg_ear = (left_ear + right_ear) / 2.0
                ear_values.append(avg_ear)
                
                # 머리 포즈 계산
                head_pose = calculate_head_pose(face_landmarks, frame.shape)
                if head_pose:
                    head_poses.append(head_pose)
            
            # 진행률 표시
            elapsed = time.time() - start_time
            progress = (elapsed / measure_time) * 100
            print(f"\r[INFO] 기준값 측정 진행률: {progress:.1f}%", end="")
        
        print("\n[INFO] 기준값 측정 완료!")
        
        if ear_values and head_poses:
            baseline = {
                "ear": {
                    "mean": np.mean(ear_values),
                    "std": np.std(ear_values),
                    "min": np.min(ear_values),
                    "max": np.max(ear_values)
                },
                "head_pose": {
                    "pitch": {
                        "mean": np.mean([p['pitch'] for p in head_poses]),
                        "std": np.std([p['pitch'] for p in head_poses])
                    },
                    "yaw": {
                        "mean": np.mean([p['yaw'] for p in head_poses]),
                        "std": np.std([p['yaw'] for p in head_poses])
                    },
                    "roll": {
                        "mean": np.mean([p['roll'] for p in head_poses]),
                        "std": np.std([p['roll'] for p in head_poses])
                    }
                }
            }
            
            save_baseline(baseline)
            print(f"[INFO] 기준값 저장 완료: {BASELINE_FILE}")
            return baseline
        
        return None

def detect_drowsiness(ear, baseline):
    """졸음 감지를 수행합니다."""
    if baseline is None:
        return False
    
    ear_threshold = baseline["ear"]["mean"] - (RATIOS["EYE_AR_RATIO"] * baseline["ear"]["std"])
    return ear < ear_threshold

def detect_gaze_deviation(head_pose, baseline):
    """시선 이탈을 감지합니다."""
    if baseline is None or head_pose is None:
        return False
    
    pitch_threshold = RATIOS["PITCH_RATIO"] * baseline["head_pose"]["pitch"]["std"]
    yaw_threshold = RATIOS["YAW_RATIO"] * baseline["head_pose"]["yaw"]["std"]
    roll_threshold = RATIOS["ROLL_RATIO"] * baseline["head_pose"]["roll"]["std"]
    
    pitch_deviation = abs(head_pose["pitch"] - baseline["head_pose"]["pitch"]["mean"])
    yaw_deviation = abs(head_pose["yaw"] - baseline["head_pose"]["yaw"]["mean"])
    roll_deviation = abs(head_pose["roll"] - baseline["head_pose"]["roll"]["mean"])
    
    return (pitch_deviation > pitch_threshold or 
            yaw_deviation > yaw_threshold or 
            roll_deviation > roll_threshold)

def detect_phone_usage(frame):
    """휴대폰 사용을 감지합니다."""
    results = model(frame, verbose=False)
    
    for result in results:
        boxes = result.boxes
        if boxes is not None:
            for box in boxes:
                cls = int(box.cls[0])
                conf = float(box.conf[0])
                
                # 클래스 0이 휴대폰이라고 가정
                if cls == 0 and conf > args.face_threshold:
                    return True
    
    return False

def main():
    """메인 함수"""
    print("[INFO] AI 모델 초기화 중...")
    
    # 카메라 초기화
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("[ERROR] 카메라를 열 수 없습니다.")
        return
    
    # 기준값 로드 또는 측정
    baseline = load_baseline()
    if baseline is None:
        print("[INFO] 기준값이 없습니다. 새로운 기준값을 측정합니다.")
        baseline = measure_baseline(cap, args.measure_time)
        if baseline is None:
            print("[ERROR] 기준값 측정에 실패했습니다.")
            return
    
    print("[INFO] 기준값 로드 완료")
    print(f"[INFO] 사용자 ID: {args.user_id}")
    print(f"[INFO] MQTT 활성화: {args.mqtt_enabled}")
    
    # MediaPipe 초기화
    with mp_face_mesh.FaceMesh(
        max_num_faces=1,
        refine_landmarks=True,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5
    ) as face_mesh:
        
        # 알림 상태 추적
        alert_states = {
            "drowsiness": {"active": False, "last_alert": 0},
            "gaze_deviation": {"active": False, "last_alert": 0},
            "phone_usage": {"active": False, "last_alert": 0}
        }
        
        alert_cooldown = 5.0  # 5초 쿨다운
        
        print("[INFO] 실시간 감지 시작...")
        
        while True:
            ret, frame = cap.read()
            if not ret:
                continue
            
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            results = face_mesh.process(frame_rgb)
            
            current_time = time.time()
            
            # 얼굴 감지
            if results.multi_face_landmarks:
                face_landmarks = results.multi_face_landmarks[0]
                
                # 눈 종횡비 계산
                left_eye = []
                right_eye = []
                
                for idx in FACIAL_LANDMARKS_IDXS["left_eye"]:
                    point = face_landmarks.landmark[idx]
                    left_eye.append([point.x * frame.shape[1], point.y * frame.shape[0]])
                
                for idx in FACIAL_LANDMARKS_IDXS["right_eye"]:
                    point = face_landmarks.landmark[idx]
                    right_eye.append([point.x * frame.shape[1], point.y * frame.shape[0]])
                
                left_ear = eye_aspect_ratio(np.array(left_eye))
                right_ear = eye_aspect_ratio(np.array(right_eye))
                avg_ear = (left_ear + right_ear) / 2.0
                
                # 머리 포즈 계산
                head_pose = calculate_head_pose(face_landmarks, frame.shape)
                
                # 졸음 감지
                if detect_drowsiness(avg_ear, baseline):
                    if not alert_states["drowsiness"]["active"] and \
                       current_time - alert_states["drowsiness"]["last_alert"] > alert_cooldown:
                        print("[ALERT] 졸음 감지!")
                        if mqtt_manager:
                            mqtt_manager.publish_alert("drowsiness", {
                                "ear": avg_ear,
                                "threshold": baseline["ear"]["mean"] - (RATIOS["EYE_AR_RATIO"] * baseline["ear"]["std"])
                            })
                        alert_states["drowsiness"]["active"] = True
                        alert_states["drowsiness"]["last_alert"] = current_time
                else:
                    alert_states["drowsiness"]["active"] = False
                
                # 시선 이탈 감지
                if head_pose and detect_gaze_deviation(head_pose, baseline):
                    if not alert_states["gaze_deviation"]["active"] and \
                       current_time - alert_states["gaze_deviation"]["last_alert"] > alert_cooldown:
                        print("[ALERT] 시선 이탈 감지!")
                        if mqtt_manager:
                            mqtt_manager.publish_alert("gaze_deviation", {
                                "head_pose": head_pose,
                                "baseline": baseline["head_pose"]
                            })
                        alert_states["gaze_deviation"]["active"] = True
                        alert_states["gaze_deviation"]["last_alert"] = current_time
                else:
                    alert_states["gaze_deviation"]["active"] = False
            
            # 휴대폰 사용 감지
            if detect_phone_usage(frame):
                if not alert_states["phone_usage"]["active"] and \
                   current_time - alert_states["phone_usage"]["last_alert"] > alert_cooldown:
                    print("[ALERT] 휴대폰 사용 감지!")
                    if mqtt_manager:
                        mqtt_manager.publish_alert("phone_usage", {
                            "confidence": 0.9,
                            "location": "detected"
                        })
                    alert_states["phone_usage"]["active"] = True
                    alert_states["phone_usage"]["last_alert"] = current_time
            else:
                alert_states["phone_usage"]["active"] = False
            
            # 화면에 정보 표시
            cv2.putText(frame, f"User: {args.user_id}", (10, 30), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
            
            if results.multi_face_landmarks:
                cv2.putText(frame, f"EAR: {avg_ear:.3f}", (10, 60), 
                           cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                
                if head_pose:
                    cv2.putText(frame, f"Pitch: {head_pose['pitch']:.1f}", (10, 90), 
                               cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                    cv2.putText(frame, f"Yaw: {head_pose['yaw']:.1f}", (10, 120), 
                               cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                    cv2.putText(frame, f"Roll: {head_pose['roll']:.1f}", (10, 150), 
                               cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
            
            # 알림 상태 표시
            y_offset = 180
            for alert_type, state in alert_states.items():
                color = (0, 0, 255) if state["active"] else (0, 255, 0)
                cv2.putText(frame, f"{alert_type}: {'ACTIVE' if state['active'] else 'OK'}", 
                           (10, y_offset), cv2.FONT_HERSHEY_SIMPLEX, 0.6, color, 2)
                y_offset += 30
            
            # MQTT 상태 표시
            mqtt_status = "CONNECTED" if mqtt_manager and mqtt_manager.connected else "DISCONNECTED"
            mqtt_color = (0, 255, 0) if mqtt_manager and mqtt_manager.connected else (0, 0, 255)
            cv2.putText(frame, f"MQTT: {mqtt_status}", (10, y_offset), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.6, mqtt_color, 2)
            
            cv2.imshow('AI Driver Monitoring', frame)
            
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break
    
    # 정리
    cap.release()
    cv2.destroyAllWindows()
    
    if mqtt_manager:
        mqtt_manager.disconnect()
    
    print("[INFO] 프로그램 종료")

if __name__ == "__main__":
    main()
