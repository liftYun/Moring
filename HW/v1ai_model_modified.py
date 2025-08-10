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

# 라이브러리 자동 설치 및 확인
def check_and_install_libraries():
    """필요한 라이브러리들을 확인하고 설치합니다."""
    required_libraries = {
        'face_recognition': 'face-recognition',
        'ultralytics': 'ultralytics'
    }
    
    missing_libraries = []
    
    for lib_name, pip_name in required_libraries.items():
        try:
            __import__(lib_name)
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
# 실행 인자 설정
# ---------------------------
parser = argparse.ArgumentParser()
parser.add_argument("--user_id", type=str, default="DriverA")
parser.add_argument("--measure_time", type=int, default=300)  # baseline 측정 시간(초)
parser.add_argument("--eye_ar_ratio", type=float, default=0.6)  # 더 관대하게 (0.8 → 0.6)
parser.add_argument("--pitch_ratio", type=float, default=2.0)   # 더 관대하게 (1.5 → 2.0)
parser.add_argument("--yaw_ratio", type=float, default=3.0)     # 더 관대하게 (2.0 → 3.0)
parser.add_argument("--roll_ratio", type=float, default=2.0)    # 더 관대하게 (1.2 → 2.0)
parser.add_argument("--face_threshold", type=float, default=0.45)  # 얼굴 인식 임계값 (0.45 = 더 엄격)
parser.add_argument("--test_mode", action="store_true")
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
# 상태 추적을 위한 전역 변수
# ---------------------------
COUNTER_DROWSY_EYE = 0
COUNTER_GAZE_DEVIATION = 0
COUNTER_PHONE_USAGE = 0

LAST_DROWSY_TIME = 0
LAST_GAZE_TIME = 0
LAST_PHONE_USAGE_TIME = 0

WARNING_COOLDOWN_TIME = 5  # 5초로 증가 (2 → 5)

# ---------------------------
# Baseline 관리 함수들
# ---------------------------
def load_baseline(file_path, user_id):
    """사용자별 baseline 데이터를 로드합니다."""
    if not os.path.exists(file_path):
        return None
    with open(file_path, "r") as f:
        data = json.load(f)
    return data.get(user_id)

def save_baseline(file_path, user_id, baseline):
    """사용자별 baseline 데이터를 저장합니다."""
    data = {}
    if os.path.exists(file_path):
        with open(file_path, "r") as f:
            data = json.load(f)
    data[user_id] = baseline
    with open(file_path, "w") as f:
        json.dump(data, f, indent=4)
    print(f"[INFO] Baseline saved for {user_id}")

def auto_measure_baseline(user_id, measure_time):
    """사용자의 정상 상태를 측정하여 baseline을 생성합니다."""
    print(f"[INFO] Measuring baseline for {user_id} for {measure_time} seconds...")
    print("[INFO] Please look at the camera normally. (eyes open, head straight)")
    
    cap = cv2.VideoCapture(0)
    start_time = time.time()
    ear_values, pitch_values, yaw_values, roll_values = [], [], [], []
    
    with mp_face_mesh.FaceMesh(
        max_num_faces=1,
        refine_landmarks=True,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5
    ) as face_mesh:
        while time.time() - start_time < measure_time:
            ret, frame = cap.read()
            if not ret:
                break
                
            frame = cv2.flip(frame, 1)
            img_h, img_w = frame.shape[:2]
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            results = face_mesh.process(rgb_frame)
            
            if results.multi_face_landmarks:
                for face_landmarks in results.multi_face_landmarks:
                    # EAR 계산
                    left_eye_points = [(int(face_landmarks.landmark[i].x * img_w), 
                                       int(face_landmarks.landmark[i].y * img_h)) 
                                      for i in [33, 160, 158, 133, 153, 144]]
                    right_eye_points = [(int(face_landmarks.landmark[i].x * img_w), 
                                        int(face_landmarks.landmark[i].y * img_h)) 
                                       for i in [362, 385, 387, 373, 380, 374]]
                    
                    left_ear = calculate_ear(left_eye_points)
                    right_ear = calculate_ear(right_eye_points)
                    ear = (left_ear + right_ear) / 2.0
                    
                    # 고개 자세 계산
                    pitch, yaw, roll = estimate_head_pose(face_landmarks, frame.shape)
                    
                    if pitch is not None and yaw is not None and roll is not None:
                        ear_values.append(ear)
                        pitch_values.append(abs(pitch))
                        yaw_values.append(abs(yaw))
                        roll_values.append(abs(roll))
            
            # 진행률 표시
            elapsed = time.time() - start_time
            progress = int((elapsed / measure_time) * 100)
            cv2.putText(frame, f"Measuring Baseline... {progress}%", (50, 50),
                        cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
            cv2.putText(frame, f"Time left: {measure_time - int(elapsed)}s", (50, 100),
                        cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
            
            cv2.imshow('Baseline Measurement', frame)
            if cv2.waitKey(1) & 0xFF == 27:
                break
    
    cap.release()
    cv2.destroyAllWindows()
    
    if len(ear_values) == 0:
        print("[ERROR] Face not detected. Please try again.")
        return None
    
    baseline = {
        "BASELINE_EYE_AR": sum(ear_values) / len(ear_values),
        "BASELINE_PITCH": sum(pitch_values) / len(pitch_values),
        "BASELINE_YAW": sum(yaw_values) / len(yaw_values),
        "BASELINE_ROLL": sum(roll_values) / len(roll_values)
    }
    
    save_baseline(BASELINE_FILE, user_id, baseline)
    print(f"[INFO] Baseline measurement complete: {baseline}")
    return baseline

# ---------------------------
# 기존 함수들 (v1ai_model.py에서 가져옴)
# ---------------------------
def calculate_ear(eye_landmarks):
    """눈의 EAR(Eye Aspect Ratio)를 계산합니다."""
    A = dist.euclidean(eye_landmarks[1], eye_landmarks[5])
    B = dist.euclidean(eye_landmarks[2], eye_landmarks[4])
    C = dist.euclidean(eye_landmarks[0], eye_landmarks[3])
    ear = (A + B) / (2.0 * C)
    return ear

def estimate_head_pose(face_landmarks, image_shape):
    """고개 자세(Pitch, Yaw, Roll)를 추정합니다."""
    img_h, img_w, _ = image_shape
    
    model_points = np.array([
        (0.0, 0.0, 0.0),            # 1: Nose tip
        (0.0, -330.0, -65.0),       # 152: Chin
        (-225.0, 170.0, -135.0),    # 33: Left eye left corner
        (225.0, 170.0, -135.0),     # 263: Right eye right corner
        (-150.0, -150.0, -125.0),   # 61: Left mouth corner
        (150.0, -150.0, -125.0)     # 291: Right mouth corner
    ], dtype="double")

    if len(face_landmarks.landmark) < 468:
        return None, None, None

    image_points = np.array([
        (face_landmarks.landmark[1].x * img_w, face_landmarks.landmark[1].y * img_h),
        (face_landmarks.landmark[152].x * img_w, face_landmarks.landmark[152].y * img_h),
        (face_landmarks.landmark[33].x * img_w, face_landmarks.landmark[33].y * img_h),
        (face_landmarks.landmark[263].x * img_w, face_landmarks.landmark[263].y * img_h),
        (face_landmarks.landmark[61].x * img_w, face_landmarks.landmark[61].y * img_h),
        (face_landmarks.landmark[291].x * img_w, face_landmarks.landmark[291].y * img_h)
    ], dtype="double")

    focal_length = 1 * img_w
    center = (img_w / 2, img_h / 2)
    camera_matrix = np.array(
        [[focal_length, 0, center[0]],
         [0, focal_length, center[1]],
         [0, 0, 1]], dtype="double"
    )

    dist_coeffs = np.zeros((4, 1))

    success, rotation_vector, translation_vector = cv2.solvePnP(
        model_points, image_points, camera_matrix, dist_coeffs, flags=cv2.SOLVEPNP_ITERATIVE
    )

    if not success:
        return None, None, None

    rmat, _ = cv2.Rodrigues(rotation_vector)
    
    sy = np.sqrt(rmat[0,0] * rmat[0,0] + rmat[1,0] * rmat[1,0])
    singular = sy < 1e-6

    if not singular:
        x = np.arctan2(rmat[2,1], rmat[2,2])
        y = np.arctan2(-rmat[2,0], sy)
        z = np.arctan2(rmat[1,0], rmat[0,0])
    else:
        x = np.arctan2(-rmat[1,2], rmat[1,1])
        y = np.arctan2(-rmat[2,0], sy)
        z = 0

    pitch = np.degrees(x)
    yaw = np.degrees(y)
    roll = np.degrees(z)

    return pitch, yaw, roll

def draw_face_landmarks(frame, face_landmarks):
    """얼굴 랜드마크를 그립니다."""
    mp_drawing.draw_landmarks(
        image=frame,
        landmark_list=face_landmarks,
        connections=mp_face_mesh.FACEMESH_TESSELATION,
        landmark_drawing_spec=None,
        connection_drawing_spec=mp_drawing_styles.get_default_face_mesh_tesselation_style())
    mp_drawing.draw_landmarks(
        image=frame,
        landmark_list=face_landmarks,
        connections=mp_face_mesh.FACEMESH_CONTOURS,
        landmark_drawing_spec=None,
        connection_drawing_spec=mp_drawing_styles.get_default_face_mesh_contours_style())
    mp_drawing.draw_landmarks(
        image=frame,
        landmark_list=face_landmarks,
        connections=mp_face_mesh.FACEMESH_IRISES,
        landmark_drawing_spec=None,
        connection_drawing_spec=mp_drawing_styles.get_default_face_mesh_iris_connections_style())

def display_info_on_frame(frame, screen_width, avg_ear, pitch, yaw, roll, baseline=None):
    """화면에 정보를 표시합니다."""
    cv2.putText(frame, f"EAR: {avg_ear:.2f}", (screen_width - 200, 120),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 0, 0), 2)
    cv2.putText(frame, f"Pitch: {pitch:.1f}", (screen_width - 200, 30),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
    cv2.putText(frame, f"Yaw: {yaw:.1f}", (screen_width - 200, 60),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
    cv2.putText(frame, f"Roll: {roll:.1f}", (screen_width - 200, 90),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
    
    if baseline:
        cv2.putText(frame, f"Baseline EAR: {baseline['BASELINE_EYE_AR']:.2f}", (screen_width - 200, 150),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 2)

# ---------------------------
# 개인화된 감지 함수들
# ---------------------------
def check_drowsiness_personalized(frame, avg_ear, pitch, baseline, ratios, current_time):
    """개인화된 baseline을 사용한 졸음 감지"""
    global COUNTER_DROWSY_EYE, LAST_DROWSY_TIME
    
    drowsiness_detected = False
    terminal_message = ""

    # 개인화된 임계값 계산
    eye_threshold = baseline["BASELINE_EYE_AR"] * ratios["EYE_AR_RATIO"]
    pitch_threshold = baseline["BASELINE_PITCH"] * ratios["PITCH_RATIO"]

    # 눈 감김 조건 (더 엄격하게)
    is_eyes_closed = (avg_ear < eye_threshold)
    # 고개 떨굼 조건 (더 엄격하게)
    is_head_down = (pitch < pitch_threshold)
    
    # 추가 조건: 눈이 완전히 감겼는지 확인 (EAR이 매우 낮을 때만)
    is_eyes_very_closed = (avg_ear < eye_threshold * 0.8)  # 20% 더 낮을 때

    # 졸음 판단: 눈이 매우 감겼고 + 고개가 떨구어졌을 때만
    if is_eyes_very_closed and is_head_down:
        COUNTER_DROWSY_EYE += 1
    elif is_eyes_closed and is_head_down:
        # 일반적인 눈 감김 + 고개 떨굼은 카운터를 절반만 증가
        COUNTER_DROWSY_EYE += 0.5
    else:
        COUNTER_DROWSY_EYE = 0

    if COUNTER_DROWSY_EYE >= 10:  # 10프레임 연속
        drowsiness_detected = True
        if current_time - LAST_DROWSY_TIME > WARNING_COOLDOWN_TIME:
            cv2.putText(frame, "DROWSINESS ALERT! (Personalized)", (50, 50),
                        cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
            terminal_message = f"DROWSINESS DETECTED: EAR={avg_ear:.2f}(<{eye_threshold:.2f}), Pitch={pitch:.1f}(<{pitch_threshold:.1f})"
            LAST_DROWSY_TIME = current_time
    
    return drowsiness_detected, terminal_message

def check_distraction_personalized(frame, yaw, roll, baseline, ratios, current_time):
    """개인화된 baseline을 사용한 시선 이탈 감지"""
    global COUNTER_GAZE_DEVIATION, LAST_GAZE_TIME

    gaze_deviation_detected = False
    terminal_message = ""

    # 개인화된 임계값 계산
    yaw_threshold = baseline["BASELINE_YAW"] * ratios["YAW_RATIO"]
    roll_threshold = baseline["BASELINE_ROLL"] * ratios["ROLL_RATIO"]

    # 더 엄격한 조건: Yaw와 Roll이 모두 임계값을 초과할 때만
    yaw_deviation = abs(yaw) > yaw_threshold
    roll_deviation = abs(roll) > roll_threshold
    
    # 둘 다 벗어났을 때만 카운터 증가 (스트레칭 등 일시적인 움직임 무시)
    if yaw_deviation and roll_deviation:
        COUNTER_GAZE_DEVIATION += 1
    elif yaw_deviation or roll_deviation:
        # 하나만 벗어났을 때는 카운터를 절반만 증가
        COUNTER_GAZE_DEVIATION += 0.5
    else:
        COUNTER_GAZE_DEVIATION = 0

    if COUNTER_GAZE_DEVIATION >= 10:  # 10프레임 연속
        gaze_deviation_detected = True
        if current_time - LAST_GAZE_TIME > WARNING_COOLDOWN_TIME:
            cv2.putText(frame, "DISTRACTION ALERT! (Personalized)", (50, 150),
                        cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 255), 2)
            terminal_message = f"DISTRACTION DETECTED: Yaw={yaw:.1f}(>{yaw_threshold:.1f}), Roll={roll:.1f}(>{roll_threshold:.1f})"
            LAST_GAZE_TIME = current_time
            
    return gaze_deviation_detected, terminal_message

# ---------------------------
# 휴대폰 감지 함수들
# ---------------------------
def run_object_detection(model, frame):
    """YOLO 모델을 사용한 객체 감지"""
    results = model(frame, verbose=False)
    detected_objects = []
    for r in results:
        boxes = r.boxes
        for box in boxes:
            class_id = int(box.cls)
            class_name = model.names[class_id]
            conf = float(box.conf)
            if class_name == 'device' and conf > 0.5:
                x1, y1, x2, y2 = map(int, box.xyxy[0])
                detected_objects.append({'class': class_name, 'bbox': [x1, y1, x2, y2], 'conf': conf})
    return detected_objects

def check_phone_usage(frame, detected_objects, current_time):
    """휴대폰 사용 감지"""
    global COUNTER_PHONE_USAGE, LAST_PHONE_USAGE_TIME

    phone_usage_detected = False
    terminal_message = ""

    if detected_objects:
        COUNTER_PHONE_USAGE += 1
        for obj in detected_objects:
            if obj['class'] == 'device':
                bbox = obj['bbox']
                cv2.rectangle(frame, (bbox[0], bbox[1]), (bbox[2], bbox[3]), (0, 255, 0), 2)
                cv2.putText(frame, "Device", (bbox[0], bbox[1] - 10), 
                           cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)
    else:
        COUNTER_PHONE_USAGE = 0

    if COUNTER_PHONE_USAGE >= 10:  # 10프레임 연속 (5 → 10)
        phone_usage_detected = True
        if current_time - LAST_PHONE_USAGE_TIME > WARNING_COOLDOWN_TIME:
            cv2.putText(frame, "PHONE USAGE DETECTED!", (50, 200),
                        cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 165, 255), 2)
            terminal_message = "PHONE USAGE DETECTED"
            LAST_PHONE_USAGE_TIME = current_time
    
    return phone_usage_detected, terminal_message

# ---------------------------
# 얼굴 인식 함수들
# ---------------------------
def load_registered_faces():
    """등록된 얼굴 데이터를 로드합니다."""
    if os.path.exists(FACE_DB_PATH):
        with open(FACE_DB_PATH, 'r') as f:
            data = json.load(f)
        return {name: np.array(enc) for name, enc in data.items()}
    return {}

def save_registered_faces(registered_faces):
    """얼굴 데이터를 저장합니다."""
    serializable_faces = {name: enc.tolist() for name, enc in registered_faces.items()}
    with open(FACE_DB_PATH, 'w') as f:
        json.dump(serializable_faces, f, indent=4)

def register_driver_face_multi_angle(frame, user_name, angle_count=3):
    """여러 각도에서 운전자 얼굴을 등록합니다."""
    face_locations = face_recognition.face_locations(frame)
    if not face_locations or len(face_locations) > 1:
        cv2.putText(frame, "Face not detected properly!", (50, 250), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2)
        return False
    
    encoding = face_recognition.face_encodings(frame, face_locations)[0]
    faces = load_registered_faces()
    
    # 다중 각도 등록을 위한 키 생성
    base_key = user_name
    if base_key not in faces:
        faces[base_key] = []  # 리스트로 초기화
    
    # 기존 등록된 얼굴이 단일 인코딩이면 리스트로 변환
    if not isinstance(faces[base_key], list):
        faces[base_key] = [faces[base_key]]
    
    # 새로운 인코딩 추가
    faces[base_key].append(encoding)
    
    # 최대 개수 제한 (메모리 효율성)
    if len(faces[base_key]) > angle_count:
        faces[base_key] = faces[base_key][-angle_count:]
    
    save_registered_faces(faces)
    
    cv2.putText(frame, f"Registered: {user_name} ({len(faces[base_key])}/{angle_count})", (50, 250), 
               cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
    print(f"[INFO] Multi-angle face registration for {user_name}: {len(faces[base_key])}/{angle_count}")
    return True

def identify_driver_strict(frame):
    """엄격한 운전자 식별 (더 정확한 인식)"""
    face_locations = face_recognition.face_locations(frame)
    if not face_locations or len(face_locations) > 1:
        cv2.putText(frame, "Face not detected properly.", (50, 250), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2)
        return None
    
    encoding = face_recognition.face_encodings(frame, face_locations)[0]
    faces = load_registered_faces()
    
    if not faces:
        cv2.putText(frame, "No registered drivers found.", (50, 250), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2)
        return None
    
    best_match_name = None
    best_match_distance = float('inf')
    
    # 각 등록된 사용자에 대해 최적의 매치 찾기
    for user_name, user_encodings in faces.items():
        if isinstance(user_encodings, list):
            # 다중 각도 등록된 경우
            distances = face_recognition.face_distance(user_encodings, encoding)
            min_distance = np.min(distances)
        else:
            # 단일 등록된 경우
            min_distance = face_recognition.face_distance([user_encodings], encoding)[0]
        
        if min_distance < best_match_distance:
            best_match_distance = min_distance
            best_match_name = user_name
    
    # 엄격한 임계값 설정
    STRICT_THRESHOLD = 0.35  # 매우 엄격
    NORMAL_THRESHOLD = args.face_threshold  # 일반 임계값
    
    confidence = (1 - best_match_distance) * 100
    
    if best_match_distance < STRICT_THRESHOLD:
        # 매우 확실한 매치
        cv2.putText(frame, f"Welcome, {best_match_name}! ({confidence:.1f}%)", (50, 250), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
        print(f"[INFO] Driver identified (STRICT): {best_match_name} (Distance: {best_match_distance:.3f}, Confidence: {confidence:.1f}%)")
        return best_match_name
    elif best_match_distance < NORMAL_THRESHOLD:
        # 의심스러운 매치 - 추가 확인 필요
        cv2.putText(frame, f"Uncertain: {best_match_name} ({confidence:.1f}%)", (50, 250), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 165, 255), 2)  # 주황색
        print(f"[WARNING] Uncertain match: {best_match_name} (Distance: {best_match_distance:.3f}, Confidence: {confidence:.1f}%)")
        return None  # 확실하지 않으면 None 반환
    else:
        # 매치 실패
        cv2.putText(frame, f"Unknown Driver! (Best: {best_match_distance:.3f})", (50, 250), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2)
        print(f"[WARNING] Unknown driver detected (Best distance: {best_match_distance:.3f})")
        return None

def test_face_recognition_accuracy():
    """얼굴 인식 정확도 테스트"""
    print("\n=== 얼굴 인식 정확도 테스트 ===")
    print("1. 본인 얼굴을 여러 각도에서 등록하세요 (R키)")
    print("2. 다른 사람 얼굴로 테스트해보세요")
    print("3. 본인 얼굴로 다시 테스트해보세요")
    print("4. Q키로 종료")
    
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("Error: Cannot open webcam.")
        return
    
    while True:
        ret, frame = cap.read()
        if not ret:
            break
            
        frame = cv2.flip(frame, 1)
        
        # 얼굴 검출
        face_locations = face_recognition.face_locations(frame)
        if face_locations:
            # 얼굴 박스 그리기
            for (top, right, bottom, left) in face_locations:
                cv2.rectangle(frame, (left, top), (right, bottom), (0, 255, 0), 2)
        
        # 안내 텍스트
        cv2.putText(frame, "Press R: Register, I: Identify, Q: Quit", (10, 30), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
        
        cv2.imshow("Face Recognition Test", frame)
        
        key = cv2.waitKey(1) & 0xFF
        if key == ord('q'):
            break
        elif key == ord('r'):
            if register_driver_face_multi_angle(frame, "test_user"):
                print("Face registered successfully!")
        elif key == ord('i'):
            result = identify_driver_strict(frame)
            if result:
                print(f"Identified: {result}")
            else:
                print("Identification failed or uncertain")
    
    cap.release()
    cv2.destroyAllWindows()

def clear_face_database():
    """등록된 얼굴 데이터베이스를 초기화합니다."""
    faces = {}
    save_registered_faces(faces)
    print("[INFO] Face database cleared.")

def show_face_recognition_info():
    """얼굴 인식 정보를 표시합니다."""
    faces = load_registered_faces()
    print("\n=== 등록된 얼굴 정보 ===")
    if not faces:
        print("등록된 얼굴이 없습니다.")
        return
    
    for user_name, encodings in faces.items():
        if isinstance(encodings, list):
            print(f"{user_name}: {len(encodings)}개 각도 등록됨")
        else:
            print(f"{user_name}: 1개 등록됨")

def improve_face_recognition():
    """얼굴 인식 개선 가이드"""
    print("\n=== 얼굴 인식 개선 방법 ===")
    print("1. 좋은 조명에서 등록하세요")
    print("2. 여러 각도에서 등록하세요 (정면, 좌측, 우측)")
    print("3. 안경, 모자 등 액세서리를 제거하고 등록하세요")
    print("4. 임계값 조정:")
    print("   - 0.35: 매우 엄격 (다른 사람 차단, 본인도 실패 가능)")
    print("   - 0.45: 엄격 (권장)")
    print("   - 0.55: 보통")
    print("   - 0.65: 관대 (다른 사람도 통과 가능)")
    print("\n사용법:")
    print("python v1ai_model_modified.py --face_threshold 0.45")
    print("python v1ai_model_modified.py --test_mode  # 테스트 모드")

# ---------------------------
# 메인 모니터링 함수
# ---------------------------
def run_driver_monitoring_system():
    """메인 운전자 모니터링 시스템"""
    global COUNTER_DROWSY_EYE, COUNTER_GAZE_DEVIATION, COUNTER_PHONE_USAGE
    global LAST_DROWSY_TIME, LAST_GAZE_TIME, LAST_PHONE_USAGE_TIME

    # 테스트 모드인 경우 얼굴 인식 정확도 테스트 실행
    if args.test_mode:
        test_face_recognition_accuracy()
        return

    # Baseline 로드 또는 측정
    baseline = load_baseline(BASELINE_FILE, args.user_id)
    if not baseline:
        print(f"[INFO] No baseline found for {args.user_id}. Starting measurement...")
        baseline = auto_measure_baseline(args.user_id, args.measure_time)
        if not baseline:
            print("[ERROR] Baseline measurement failed.")
            return

    print(f"[INFO] Using baseline for {args.user_id}: {baseline}")

    # 웹캠 초기화
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("Error: Cannot open webcam.")
        return

    screen_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    screen_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

    # 눈 랜드마크 인덱스
    LEFT_EYE_LANDMARKS = [33, 160, 158, 133, 153, 144]
    RIGHT_EYE_LANDMARKS = [362, 385, 387, 373, 380, 374]

    identification_status = "Not Identified"
    user_to_register = args.user_id

    # MediaPipe Face Mesh 초기화
    with mp_face_mesh.FaceMesh(
        max_num_faces=1,
        refine_landmarks=True,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5
    ) as face_mesh:

        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                print("Failed to grab frame.")
                break

            frame = cv2.flip(frame, 1)
            image_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            image_rgb.flags.writeable = False
            results = face_mesh.process(image_rgb)
            image_rgb.flags.writeable = True
            frame = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2BGR)

            drowsiness_status_message = ""
            distraction_status_message = ""
            phone_usage_status_message = ""

            # 객체 감지
            detected_objects = run_object_detection(model, frame)

            pitch, yaw, roll = None, None, None

            if results.multi_face_landmarks:
                for face_landmarks in results.multi_face_landmarks:
                    # 얼굴 랜드마크 그리기
                    draw_face_landmarks(frame, face_landmarks)

                    # EAR 계산
                    left_eye_points = [(int(face_landmarks.landmark[i].x * screen_width),
                                       int(face_landmarks.landmark[i].y * screen_height))
                                      for i in LEFT_EYE_LANDMARKS]
                    right_eye_points = [(int(face_landmarks.landmark[i].x * screen_width),
                                        int(face_landmarks.landmark[i].y * screen_height))
                                       for i in RIGHT_EYE_LANDMARKS]
                    avg_ear = (calculate_ear(left_eye_points) + calculate_ear(right_eye_points)) / 2.0

                    # 고개 자세 추정
                    pitch, yaw, roll = estimate_head_pose(face_landmarks, frame.shape)

                    if pitch is not None and yaw is not None and roll is not None:
                        # 개인화된 감지 함수들 호출
                        _, drowsiness_status_message = check_drowsiness_personalized(
                            frame, avg_ear, pitch, baseline, RATIOS, time.time())
                        
                        _, distraction_status_message = check_distraction_personalized(
                            frame, yaw, roll, baseline, RATIOS, time.time())
                        
                        _, phone_usage_status_message = check_phone_usage(
                            frame, detected_objects, time.time())

                        # 정보 표시
                        display_info_on_frame(frame, screen_width, avg_ear, pitch, yaw, roll, baseline)
            else:
                # 얼굴이 감지되지 않으면 카운터 초기화
                COUNTER_DROWSY_EYE = 0
                COUNTER_GAZE_DEVIATION = 0
                COUNTER_PHONE_USAGE = 0

            # 상태 및 조작 가이드 표시
            cv2.putText(frame, f"ID Status: {identification_status}", (50, screen_height - 60),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)
            cv2.putText(frame, "R:Register I:Identify B:Baseline +/-:Sensitivity C:Clear DB H:Help ESC:Exit",
                       (50, screen_height - 30), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 1)

            # 터미널 출력
            if drowsiness_status_message:
                print(f"[{time.strftime('%H:%M:%S', time.localtime())}] {drowsiness_status_message}")
            elif distraction_status_message:
                print(f"[{time.strftime('%H:%M:%S', time.localtime())}] {distraction_status_message}")
            elif phone_usage_status_message:
                print(f"[{time.strftime('%H:%M:%S', time.localtime())}] {phone_usage_status_message}")

            cv2.imshow('Personalized Driver Monitoring System', frame)

            # 키 입력 처리
            key = cv2.waitKey(5) & 0xFF
            if key == 27:  # ESC
                break
            elif key == ord('r'):  # Register
                print(f"Attempting to register face for '{user_to_register}'...")
                if register_driver_face_multi_angle(frame, user_to_register):
                    identification_status = f"Registered {user_to_register}"
                else:
                    identification_status = "Registration Failed"
            elif key == ord('i'):  # Identify
                print("Attempting to identify driver...")
                identified_name = identify_driver_strict(frame)
                identification_status = identified_name if identified_name else "Identification Failed"
            elif key == ord('b'):  # Re-measure Baseline
                print("Re-measuring baseline...")
                baseline = auto_measure_baseline(args.user_id, args.measure_time)
                if baseline:
                    print("Baseline re-measurement completed.")
            elif key == ord('+'):  # 감도 증가
                RATIOS["EYE_AR_RATIO"] *= 0.9
                RATIOS["PITCH_RATIO"] *= 0.9
                RATIOS["YAW_RATIO"] *= 0.9
                RATIOS["ROLL_RATIO"] *= 0.9
                print(f"[INFO] Sensitivity increased: {RATIOS}")
            elif key == ord('-'):  # 감도 감소
                RATIOS["EYE_AR_RATIO"] *= 1.1
                RATIOS["PITCH_RATIO"] *= 1.1
                RATIOS["YAW_RATIO"] *= 1.1
                RATIOS["ROLL_RATIO"] *= 1.1
                print(f"[INFO] Sensitivity decreased: {RATIOS}")
            elif key == ord('c'):  # Clear Database
                print("Clearing face database...")
                clear_face_database()
                identification_status = "Database Cleared"
            elif key == ord('h'):  # Help
                improve_face_recognition()

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    run_driver_monitoring_system()