import cv2
import mediapipe as mp
import numpy as np
from scipy.spatial import distance as dist
import time
import face_recognition # 얼굴 인식을 위한 라이브러리
import json # 로컬 JSON 파일 저장을 위함
import os # 파일 경로 처리를 위함

# Ultralytics 라이브러리에서 YOLO 모델을 임포트합니다.
from ultralytics import YOLO

# --- 1. 파일 경로 설정 ---
 # 운전자 등록 정보 저장 파일
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(BASE_DIR, "models")
DATA_DIR = os.path.join(BASE_DIR, "data")

YOLO_MODEL_PATH = os.path.join(MODEL_DIR, "best.pt")
FACE_DB_PATH = os.path.join(DATA_DIR, "registered_faces.json")

os.makedirs(MODEL_DIR, exist_ok=True)
os.makedirs(DATA_DIR, exist_ok=True)
# yolo모델 로드
if not os.path.exists(YOLO_MODEL_PATH):
    raise FileNotFoundError(f"YOLO 모델 파일을 찾을 수 없습니다: {YOLO_MODEL_PATH}")

model = YOLO(YOLO_MODEL_PATH)
# --- 2. MediaPipe 설정 ---
mp_face_mesh = mp.solutions.face_mesh
mp_drawing = mp.solutions.drawing_utils
mp_drawing_styles = mp.solutions.drawing_styles

# 3. 얼굴 데이터 로드
# ─────────────────────────────
if not os.path.exists(FACE_DB_PATH):
    with open(FACE_DB_PATH, "w") as f:
        json.dump({}, f)  # 빈 JSON 파일 생성

with open(FACE_DB_PATH, "r") as f:
    registered_faces = json.load(f)

print(f"[INFO] YOLO 모델 경로: {YOLO_MODEL_PATH}")
print(f"[INFO] 얼굴 데이터 경로: {FACE_DB_PATH}")
print(f"[INFO] 등록된 얼굴 수: {len(registered_faces)}")

# ---  감지 임계값 파라미터 (***이 부분을 반드시 사용자님 환경에 맞게 조정하세요!***) ---
# 웹캠과 사용자의 얼굴 특성, 조명 환경에 따라 이 값들이 크게 달라질 수 있습니다.
# 아래 가이드를 읽고 직접 시스템을 실행하며 화면에 표시되는 각도와 EAR 값을 관찰하여
# 적정값을 찾아 설정하는 것이 가장 중요합니다.

# --- 졸음 감지 (Drowsiness Detection) ---
EYE_AR_THRESH = 0.27 
EYE_AR_CONSEC_FRAMES = 5 # 눈 감김 AND 고개 떨굼이 몇 프레임 연속되어야 졸음으로 판단할지
PITCH_DOWN_THRESH = -160 

# --- 전방 미주시/시선 이탈 감지 (Distraction Detection) ---
YAW_THRESH = 90 
ROLL_THRESH = 8 
GAZE_CONSEC_FRAMES = 5 

# --- 경고 쿨다운 파라미터 ---
WARNING_COOLDOWN_TIME = 2 # 경고 메시지 반복 간 최소 시간 (초)

# --- 4. 휴대폰 감지 파라미터 ---
PHONE_NEAR_FACE_THRESHOLD_PX = 100 # 휴대폰이 얼굴에 가까이 있는 것으로 판단하는 픽셀 거리
PHONE_CONSEC_FRAMES = 5 # 휴대폰 사용이 몇 프레임 연속되어야 경고할지

GAZE_TO_PHONE_YAW_THRESH = 30 # 휴대폰을 볼 때 고개가 옆으로 돌아가는 Yaw 각도 임계값
GAZE_TO_PHONE_PITCH_THRESH = -10 # 휴대폰을 볼 때 고개가 아래로 숙여지는 Pitch 각도 임계값

# --- 5. 본인 확인 파라미터 ---
FACE_RECOGNITION_THRESHOLD = 0.35 # 얼굴 인식 유사도 임계값 (낮을수록 엄격)

# --- 상태 추적을 위한 전역 변수 ---
COUNTER_DROWSY_EYE = 0 
COUNTER_GAZE_DEVIATION = 0 
COUNTER_PHONE_USAGE = 0 

LAST_DROWSY_TIME = 0 
LAST_GAZE_TIME = 0 
LAST_PHONE_USAGE_TIME = 0 

# --- 함수 정의 ---

def calculate_ear(eye_landmarks):
    # 눈 랜드마크 6개 중 A, B (수직 거리), C (수평 거리)를 이용해 EAR 계산
    A = dist.euclidean(eye_landmarks[1], eye_landmarks[5])
    B = dist.euclidean(eye_landmarks[2], eye_landmarks[4])
    C = dist.euclidean(eye_landmarks[0], eye_landmarks[3])
    ear = (A + B) / (2.0 * C)
    return ear

def estimate_head_pose(face_landmarks, image_shape):
    img_h, img_w, _ = image_shape
    
    # 3D 모델 포인트 (일반적인 얼굴의 3D 좌표)
    # MediaPipe의 랜드마크 인덱스에 매핑되는 6개의 주요 포인트
    model_points = np.array([
        (0.0, 0.0, 0.0),            # 1: Nose tip
        (0.0, -330.0, -65.0),       # 152: Chin
        (-225.0, 170.0, -135.0),    # 33: Left eye left corner
        (225.0, 170.0, -135.0),     # 263: Right eye right corner
        (-150.0, -150.0, -125.0),   # 61: Left mouth corner
        (150.0, -150.0, -125.0)     # 291: Right mouth corner
    ], dtype="double")

    # MediaPipe Face Mesh는 468개의 랜드마크를 제공합니다.
    # 필요한 랜드마크 수가 부족하면 오류 방지를 위해 None 반환
    if len(face_landmarks.landmark) < 468: 
        return None, None, None

    # 2D 이미지 포인트 (현재 프레임에서 감지된 랜드마크의 픽셀 좌표)
    image_points = np.array([
        (face_landmarks.landmark[1].x * img_w, face_landmarks.landmark[1].y * img_h),
        (face_landmarks.landmark[152].x * img_w, face_landmarks.landmark[152].y * img_h),
        (face_landmarks.landmark[33].x * img_w, face_landmarks.landmark[33].y * img_h),
        (face_landmarks.landmark[263].x * img_w, face_landmarks.landmark[263].y * img_h),
        (face_landmarks.landmark[61].x * img_w, face_landmarks.landmark[61].y * img_h),
        (face_landmarks.landmark[291].x * img_w, face_landmarks.landmark[291].y * img_h)
    ], dtype="double")

    # 카메라 매트릭스 설정 (카메라의 내부 파라미터)
    # 초점 거리 (focal_length)는 이미지 너비에 비례한다고 가정
    focal_length = 1 * img_w 
    center = (img_w / 2, img_h / 2)
    camera_matrix = np.array(
        [[focal_length, 0, center[0]],
         [0, focal_length, center[1]],
         [0, 0, 1]], dtype="double"
    )

    # 왜곡 계수 (렌즈 왜곡이 없다고 가정)
    dist_coeffs = np.zeros((4, 1))

    # PnP (Perspective-n-Point) 알고리즘을 사용하여 회전 벡터와 이동 벡터 추정
    success, rotation_vector, translation_vector = cv2.solvePnP(
        model_points, image_points, camera_matrix, dist_coeffs, flags=cv2.SOLVEPNP_ITERATIVE
    )

    if not success:
        return None, None, None

    # 회전 벡터를 회전 행렬로 변환
    rmat, _ = cv2.Rodrigues(rotation_vector)
    
    # 회전 행렬에서 Pitch, Yaw, Roll (오일러 각) 추출
    # 이 부분은 OpenCV의 solvePnP 결과(rmat)를 오일러 각으로 변환하는 표준 방법입니다.
    sy = np.sqrt(rmat[0,0] * rmat[0,0] + rmat[1,0] * rmat[1,0])
    singular = sy < 1e-6 # 특이점 처리 (짐벌 락 현상 방지)

    if not singular:
        x = np.arctan2(rmat[2,1], rmat[2,2])
        y = np.arctan2(-rmat[2,0], sy)
        z = np.arctan2(rmat[1,0], rmat[0,0])
    else: 
        x = np.arctan2(-rmat[1,2], rmat[1,1])
        y = np.arctan2(-rmat[2,0], sy)
        z = 0

    pitch = np.degrees(x) # 코가 위/아래로 움직이는 각도 (앞뒤 숙임)
    yaw = np.degrees(y)   # 코가 좌/우로 움직이는 각도 (좌우 회전)
    roll = np.degrees(z)  # 귀가 어깨에 닿는 각도 (좌우 기울기)

    return pitch, yaw, roll

def draw_face_landmarks(frame, face_landmarks):
    # 얼굴 테셀레이션 그리기 (피부 표현)
    mp_drawing.draw_landmarks(
        image=frame,
        landmark_list=face_landmarks,
        connections=mp_face_mesh.FACEMESH_TESSELATION, 
        landmark_drawing_spec=None,
        connection_drawing_spec=mp_drawing_styles
        .get_default_face_mesh_tesselation_style())
    # 얼굴 윤곽선 그리기
    mp_drawing.draw_landmarks(
        image=frame,
        landmark_list=face_landmarks,
        connections=mp_face_mesh.FACEMESH_CONTOURS, 
        landmark_drawing_spec=None,
        connection_drawing_spec=mp_drawing_styles
        .get_default_face_mesh_contours_style())
    # 눈동자 연결선 그리기 (시선 추적에 사용 가능)
    mp_drawing.draw_landmarks(
        image=frame,
        landmark_list=face_landmarks,
        connections=mp_face_mesh.FACEMESH_IRISES, 
        landmark_drawing_spec=None,
        connection_drawing_spec=mp_drawing_styles
        .get_default_face_mesh_iris_connections_style())

def display_info_on_frame(frame, screen_width, avg_ear, pitch, yaw, roll):
    # 화면 우상단에 EAR 및 고개 각도 정보 표시
    cv2.putText(frame, f"EAR: {avg_ear:.2f}", (screen_width - 200, 120),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 0, 0), 2) # EAR은 빨간색
    cv2.putText(frame, f"Pitch: {pitch:.1f}", (screen_width - 200, 30),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2) # 각도는 초록색
    cv2.putText(frame, f"Yaw: {yaw:.1f}", (screen_width - 200, 60),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
    cv2.putText(frame, f"Roll: {roll:.1f}", (screen_width - 200, 90),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

def check_drowsiness(frame, avg_ear, pitch, current_time):
    """
    졸음 (눈 감김 AND 고개 떨굼)을 감지하고 경고를 표시합니다.
    Args:
        frame (np.array): 현재 비디오 프레임.
        avg_ear (float): 평균 EAR 값.
        pitch (float): Pitch 각도.
        current_time (float): 현재 시간.
    Returns:
        bool: 졸음이 감지되었는지 여부.
        str: 터미널 출력용 메시지 (감지 시).
    """
    global COUNTER_DROWSY_EYE, LAST_DROWSY_TIME
    
    drowsiness_detected = False
    terminal_message = ""

    # 눈 감김 조건
    is_eyes_closed = (avg_ear < EYE_AR_THRESH)
    # 고개 떨굼 조건
    is_head_down = (pitch < PITCH_DOWN_THRESH)

    # --- 수정된 졸음 판단 로직: 눈 감김 AND 고개 떨굼 동시 만족 시 ---
    if is_eyes_closed and is_head_down: # AND 조건
        COUNTER_DROWSY_EYE += 1 # 통합 카운터 사용
    else:
        COUNTER_DROWSY_EYE = 0 # 조건 불만족 시 카운터 초기화

    if COUNTER_DROWSY_EYE >= EYE_AR_CONSEC_FRAMES: # 통합된 카운터 사용
        drowsiness_detected = True
        if current_time - LAST_DROWSY_TIME > WARNING_COOLDOWN_TIME:
            cv2.putText(frame, "DROWSINESS ALERT! (Eyes Closed & Head Down)", (50, 50), # 메시지 변경
                        cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2) # 빨간색
            terminal_message = "DROWSINESS DETECTED: Eyes Closed & Head Down"
            LAST_DROWSY_TIME = current_time
    
    return drowsiness_detected, terminal_message

def check_distraction(frame, yaw, roll, current_time):
    """
    시선 이탈 (고개 회전 또는 기울기)을 감지하고 경고를 표시합니다.
    Args:
        frame (np.array): 현재 비디오 프레임.
        yaw (float): Yaw 각도.
        roll (float): Roll 각도.
        current_time (float): 현재 시간.
    Returns:
        bool: 시선 이탈이 감지되었는지 여부.
        str: 터미널 출력용 메시지 (감지 시).
    """
    global COUNTER_GAZE_DEVIATION, LAST_GAZE_TIME

    gaze_deviation_detected = False
    terminal_message = ""

    # Yaw 또는 Roll이 임계값을 초과하면 시선 이탈로 판단
    if abs(yaw) > YAW_THRESH or abs(roll) > ROLL_THRESH: 
        COUNTER_GAZE_DEVIATION += 1
    else: 
        COUNTER_GAZE_DEVIATION = 0

    if COUNTER_GAZE_DEVIATION >= GAZE_CONSEC_FRAMES:
        gaze_deviation_detected = True
        if current_time - LAST_GAZE_TIME > WARNING_COOLDOWN_TIME:
            cv2.putText(frame, "DISTRACTION ALERT! (Gaze Deviation)", (50, 150),
                        cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 255), 2) # 노란색
            terminal_message = "DISTRACTION DETECTED: Gaze Deviation"
            LAST_GAZE_TIME = current_time
            
    return gaze_deviation_detected, terminal_message

# --- 객체 감지 모델 로드 ---
def load_object_detection_model():
    print("Loading custom YOLOv8 'device' detection model...")
    # =========================================================================
    # !!! 중요 !!! 여기 'model_path'를 당신의 best.pt 파일 경로로 수정하세요!
    # =========================================================================
    # 예시 1: Jupyter Notebook 파일과 'runs' 폴더가 같은 디렉토리에 있을 때 (가장 흔함)
    model_path = r'C:\Users\SSAFY\Desktop\ai-model\best.pt' 
    
    # 예시 2: best.pt 파일을 프로젝트 폴더 내의 'models' 폴더로 옮겼을 때 (프로젝트 구조에 따라)
    # model_path = 'models/best.pt' 

    # 예시 3: best.pt 파일의 절대 경로를 사용할 때 (Windows 예시)
    # model_path = 'D:/my_project/runs/detect/muid_device_detection/weights/best.pt'
    # 예시 4: best.pt 파일의 절대 경로를 사용할 때 (Linux/macOS 예시)
    # model_path = '/home/your_user/your_project/runs/detect/muid_device_detection/weights/best.pt'
    
    try:
        model = YOLO(model_path) 
        print(f"Custom 'device' detection model loaded successfully from: {model_path}")
        return model
    except Exception as e:
        print(f"Error loading custom YOLOv8 model from {model_path}: {e}")
        print("Please ensure the 'best.pt' file exists at the specified path and the path is correct.")
        print("YOLOv8 모델 로드에 실패했습니다. 프로그램을 종료합니다.")
        exit() # 모델 로드 실패 시 프로그램 종료

# --- 객체 감지 추론 실행 ---
def run_object_detection(model, frame):
    # YOLOv8 모델로 프레임에서 객체 탐지 실행
    results = model(frame, verbose=False) # verbose=False로 설정하여 콘솔 출력 줄임

    detected_objects = []
    for r in results: # 각 결과 객체에 대해
        boxes = r.boxes # 감지된 바운딩 박스 정보
        for box in boxes: # 각 바운딩 박스에 대해
            class_id = int(box.cls) # 클래스 ID
            class_name = model.names[class_id] # 클래스 이름 (예: 'device')
            conf = float(box.conf) # 신뢰도 (confidence score)
            
            # MUID-IITR 모델은 'device' 클래스만 학습했으므로 'device'만 감지
            # 필요에 따라 신뢰도(conf) 임계값을 여기에 추가할 수 있습니다.
            if class_name == 'device' and conf > 0.5: # 0.5 이상 신뢰도를 가진 'device'만 포함
                x1, y1, x2, y2 = map(int, box.xyxy[0]) # 바운딩 박스 좌표 (x1, y1, x2, y2)
                detected_objects.append({'class': class_name, 'bbox': [x1, y1, x2, y2], 'conf': conf})
    return detected_objects

def check_phone_usage(frame, detected_objects, face_landmarks, current_time, screen_width, screen_height, pitch, yaw):
    """
    감지된 휴대폰(device)과 얼굴 랜드마크, 고개 자세를 기반으로 휴대폰 사용 여부를 판단합니다.
    Args:
        frame (np.array): 현재 비디오 프레임.
        detected_objects (list): run_object_detection에서 반환된 객체 리스트.
        face_landmarks: MediaPipe에서 감지된 얼굴 랜드마크 객체.
        current_time (float): 현재 시간.
        screen_width (int): 화면 너비.
        screen_height (int): 화면 높이.
        pitch (float): 현재 고개의 Pitch 각도.
        yaw (float): 현재 고개의 Yaw 각도.
    Returns:
        bool: 휴대폰 사용이 감지되었는지 여부.
        str: 터미널 출력용 메시지 (감지 시).
    """
    global COUNTER_PHONE_USAGE, LAST_PHONE_USAGE_TIME

    phone_usage_detected = False
    terminal_message = ""

    phone_detected_in_frame = False # 이번 프레임에 'device'가 감지되었는지 여부

    if face_landmarks:
        # 얼굴의 주요 랜드마크 (예: 코 끝, 눈 중앙) 좌표를 픽셀 단위로 변환
        nose_tip_x = int(face_landmarks.landmark[1].x * screen_width)
        nose_tip_y = int(face_landmarks.landmark[1].y * screen_height)
        
        # 귀 랜드마크 (통화 감지용)
        left_ear_x = int(face_landmarks.landmark[132].x * screen_width) 
        left_ear_y = int(face_landmarks.landmark[132].y * screen_height)
        right_ear_x = int(face_landmarks.landmark[361].x * screen_width) 
        right_ear_y = int(face_landmarks.landmark[361].y * screen_height)
        mouth_x = int(face_landmarks.landmark[13].x * screen_width) 
        mouth_y = int(face_landmarks.landmark[13].y * screen_height)


        for obj in detected_objects:
            # 여기서는 MUID-IITR 모델이 'device' 클래스만 감지하므로 'device'로 확인
            if obj['class'] == 'device': 
                phone_detected_in_frame = True
                bbox = obj['bbox'] # [x1, y1, x2, y2]
                phone_center_x = (bbox[0] + bbox[2]) // 2
                phone_center_y = (bbox[1] + bbox[3]) // 2

                cv2.rectangle(frame, (bbox[0], bbox[1]), (bbox[2], bbox[3]), (0, 255, 0), 2)
                cv2.putText(frame, "Device", (bbox[0], bbox[1] - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)

                # --- 1. 통화 (귀에 대는) 감지 로직 ---
                dist_to_left_ear = dist.euclidean((phone_center_x, phone_center_y), (left_ear_x, left_ear_y))
                dist_to_right_ear = dist.euclidean((phone_center_x, phone_center_y), (right_ear_x, right_ear_y))
                dist_to_mouth = dist.euclidean((phone_center_x, phone_center_y), (mouth_x, mouth_y))

                is_phone_near_face = (dist_to_left_ear < PHONE_NEAR_FACE_THRESHOLD_PX or
                                      dist_to_right_ear < PHONE_NEAR_FACE_THRESHOLD_PX or
                                      dist_to_mouth < PHONE_NEAR_FACE_THRESHOLD_PX)
                
                # --- 2. 휴대폰을 보는 (시선 분산) 감지 로직 ---
                is_gazing_at_phone = False
                
                # 휴대폰 위치와 고개 각도를 비교하여 휴대폰을 보고 있는지 판단
                # 휴대폰 중심이 코 끝보다 왼쪽에 있고, 고개가 왼쪽으로 돌아갔을 때
                if phone_center_x < nose_tip_x and yaw > GAZE_TO_PHONE_YAW_THRESH:
                    is_gazing_at_phone = True
                # 휴대폰 중심이 코 끝보다 오른쪽에 있고, 고개가 오른쪽으로 돌아갔을 때
                elif phone_center_x > nose_tip_x and yaw < -GAZE_TO_PHONE_YAW_THRESH:
                    is_gazing_at_phone = True
                # 휴대폰 중심이 아래쪽에 있고, 고개가 아래로 숙여졌을 때
                elif phone_center_y > nose_tip_y and pitch < GAZE_TO_PHONE_PITCH_THRESH:
                    is_gazing_at_phone = True

                # --- 최종 휴대폰 사용 판단 (통화 또는 시선 분산) ---
                if is_phone_near_face or is_gazing_at_phone:
                    COUNTER_PHONE_USAGE += 1
                else:
                    COUNTER_PHONE_USAGE = 0 
                
                break # 하나의 'device'만 감지한다고 가정하고 다음 프레임으로 넘어감 (성능 최적화)
    
    # 이번 프레임에 'device'가 전혀 감지되지 않았다면 카운터 초기화
    if not phone_detected_in_frame:
        COUNTER_PHONE_USAGE = 0

    if COUNTER_PHONE_USAGE >= PHONE_CONSEC_FRAMES:
        phone_usage_detected = True
        if current_time - LAST_PHONE_USAGE_TIME > WARNING_COOLDOWN_TIME:
            # 경고 메시지 업데이트: 통화 또는 시선 분산 모두 포함
            if is_phone_near_face and not is_gazing_at_phone:
                cv2.putText(frame, "PHONE CALL DETECTED!", (50, 200),
                            cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 165, 255), 2) # 주황색
                terminal_message = "PHONE USAGE DETECTED: Call"
            elif is_gazing_at_phone and not is_phone_near_face:
                cv2.putText(frame, "PHONE DISTRACTION DETECTED!", (50, 200),
                            cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 165, 255), 2) # 주황색
                terminal_message = "PHONE USAGE DETECTED: Distraction"
            else: # 둘 다 해당되거나 애매한 경우
                cv2.putText(frame, "PHONE USAGE DETECTED!", (50, 200),
                            cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 165, 255), 2) # 주황색
                terminal_message = "PHONE USAGE DETECTED"
            
            LAST_PHONE_USAGE_TIME = current_time
    
    return phone_usage_detected, terminal_message

# --- 새로운 기능: 로컬 파일 기반 운전자 등록 및 인식 ---

def load_registered_faces():
    """등록된 운전자 얼굴 인코딩을 JSON 파일에서 불러옵니다."""
    if os.path.exists(REGISTERED_FACES_FILE):
        with open(REGISTERED_FACES_FILE, 'r') as f:
            data = json.load(f)
            # JSON에 저장된 리스트를 numpy 배열로 다시 변환
            loaded_faces = {name: np.array(emb) for name, emb in data.items()}
            return loaded_faces
    return {} # 파일이 없으면 빈 딕셔너리 반환

def save_registered_faces(registered_faces):
    """등록된 운전자 얼굴 인코딩을 JSON 파일에 저장합니다."""
    # numpy 배열을 JSON 직렬화 가능한 리스트로 변환
    serializable_faces = {name: emb.tolist() for name, emb in registered_faces.items()}
    with open(REGISTERED_FACES_FILE, 'w') as f:
        json.dump(serializable_faces, f, indent=4) # 보기 좋게 들여쓰기하여 저장

def register_driver_face(frame, user_name):
    """
    현재 프레임에서 운전자의 얼굴을 감지하고 등록합니다.
    Args:
        frame (np.array): 현재 비디오 프레임.
        user_name (str): 등록할 운전자의 이름.
    Returns:
        bool: 등록 성공 여부.
    """
    # 얼굴 위치 감지 (기본 얼굴 인식 라이브러리 사용)
    face_locations = face_recognition.face_locations(frame)
    if not face_locations:
        cv2.putText(frame, "No face detected for registration!", (50, 250), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2)
        print("Registration failed: No face detected.")
        return False
    
    if len(face_locations) > 1:
        cv2.putText(frame, "Multiple faces detected! Only one person.", (50, 250), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2)
        print("Registration failed: Multiple faces detected.")
        return False

    # 감지된 얼굴의 인코딩 생성
    current_face_encoding = face_recognition.face_encodings(frame, face_locations)[0]
    
    # 기존 등록된 얼굴 데이터 불러오기
    registered_faces = load_registered_faces()

    # 새 운전자 정보 추가 또는 기존 운전자 정보 업데이트
    registered_faces[user_name] = current_face_encoding

    try:
        save_registered_faces(registered_faces) # 파일에 저장
        cv2.putText(frame, f"Registered: {user_name}", (50, 250), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
        print(f"Driver '{user_name}' registered successfully to local file.")
        return True
    except Exception as e:
        cv2.putText(frame, f"Registration failed: {e}", (50, 250), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2)
        print(f"Error registering driver to local file: {e}")
        return False

def identify_driver(frame):
    """
    현재 프레임에서 운전자의 얼굴을 감지하고 등록된 운전자와 비교하여 식별합니다.
    Args:
        frame (np.array): 현재 비디오 프레임.
    Returns:
        str: 식별된 운전자의 이름 또는 상태 메시지.
    """
    face_locations = face_recognition.face_locations(frame)
    if not face_locations:
        cv2.putText(frame, "No face detected for identification.", (50, 250), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2)
        return "No Face"
    
    if len(face_locations) > 1:
        cv2.putText(frame, "Multiple faces detected! Cannot identify.", (50, 250), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2)
        return "Multiple Faces"

    current_face_encoding = face_recognition.face_encodings(frame, face_locations)[0]

    registered_faces = load_registered_faces()
    
    if not registered_faces:
        cv2.putText(frame, "No registered drivers found.", (50, 250), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2)
        return "No Registered"

    known_face_encodings = list(registered_faces.values())
    known_face_names = list(registered_faces.keys())

    # 등록된 모든 얼굴과의 거리 계산
    face_distances = face_recognition.face_distance(known_face_encodings, current_face_encoding)
    
    # 가장 가까운(거리가 짧은) 얼굴 찾기
    best_match_index = np.argmin(face_distances)
    
    identified_name = "Unknown Driver"
    # 거리가 임계값보다 작으면 일치한다고 판단
    if face_distances[best_match_index] < FACE_RECOGNITION_THRESHOLD:
        identified_name = known_face_names[best_match_index]
        cv2.putText(frame, f"Welcome, {identified_name}!", (50, 250), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
        print(f"Driver identified: {identified_name} (Distance: {face_distances[best_match_index]:.2f})")
    else:
        cv2.putText(frame, "Unknown Driver!", (50, 250), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2)
        print(f"Unknown Driver detected (Closest Distance: {face_distances[best_match_index]:.2f})")
    
    return identified_name

# --- 메인 프로그램 ---
def run_driver_monitoring_system():
    global COUNTER_DROWSY_EYE, COUNTER_GAZE_DEVIATION, COUNTER_PHONE_USAGE
    global LAST_DROWSY_TIME, LAST_GAZE_TIME, LAST_PHONE_USAGE_TIME

    # 웹캠 열기 (0은 기본 웹캠)
    cap = cv2.VideoCapture(0)

    if not cap.isOpened():
        print("Error: Could not open webcam. Please check if camera is connected and not in use by other programs.")
        return

    # 웹캠 해상도 가져오기
    screen_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    screen_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    
    # MediaPipe에서 눈 계산에 사용되는 랜드마크 인덱스 (왼쪽/오른쪽 눈에 대한 인덱스 목록)
    LEFT_EYE_LANDMARKS = [33, 160, 158, 133, 153, 144]
    RIGHT_EYE_LANDMARKS = [362, 385, 387, 373, 380, 374]

    # YOLOv8 객체 감지 모델 로드
    object_detection_model = load_object_detection_model()

    identification_status = "Not Identified" # 운전자 식별 상태 초기화
    
    user_to_register = "Driver A" # 등록할 운전자의 기본 이름 (필요 시 변경)

    # MediaPipe Face Mesh 초기화
    with mp_face_mesh.FaceMesh(
        max_num_faces=1, # 한 번에 한 얼굴만 처리
        refine_landmarks=True, # 눈, 입 주변 랜드마크 정밀화
        min_detection_confidence=0.5, # 얼굴 감지 최소 신뢰도
        min_tracking_confidence=0.5) as face_mesh: # 얼굴 추적 최소 신뢰도

        while cap.isOpened():
            ret, frame = cap.read() # 프레임 읽기
            if not ret:
                print("Failed to grab frame. Stream might have ended.")
                break

            frame = cv2.flip(frame, 1) # 좌우 반전 (셀카 모드)
            image_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB) # MediaPipe는 RGB 이미지를 사용
            image_rgb.flags.writeable = False # 이미지 쓰기 불가능으로 설정하여 성능 최적화
            results = face_mesh.process(image_rgb) # 얼굴 랜드마크 감지
            image_rgb.flags.writeable = True # 쓰기 가능으로 다시 설정
            frame = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2BGR) # OpenCV 표시를 위해 다시 BGR로 변환

            drowsiness_status_message = ""
            distraction_status_message = ""
            phone_usage_status_message = "" 
            
            # YOLOv8 객체 감지 실행
            detected_objects = run_object_detection(object_detection_model, frame)

            pitch, yaw, roll = None, None, None # 고개 각도 초기화

            if results.multi_face_landmarks:
                for face_landmarks in results.multi_face_landmarks:
                    # 얼굴 랜드마크 그리기
                    draw_face_landmarks(frame, face_landmarks)

                    # 눈 랜드마크 추출 및 EAR 계산
                    left_eye_points = [(int(face_landmarks.landmark[i].x * screen_width), int(face_landmarks.landmark[i].y * screen_height)) for i in LEFT_EYE_LANDMARKS]
                    right_eye_points = [(int(face_landmarks.landmark[i].x * screen_width), int(face_landmarks.landmark[i].y * screen_height)) for i in RIGHT_EYE_LANDMARKS]
                    avg_ear = (calculate_ear(left_eye_points) + calculate_ear(right_eye_points)) / 2.0 

                    # 고개 자세 추정
                    pitch, yaw, roll = estimate_head_pose(face_landmarks, frame.shape)
                    
                    if pitch is not None and yaw is not None and roll is not None: 
                        # 졸음 감지
                        _, drowsiness_status_message = check_drowsiness(frame, avg_ear, pitch, time.time())
                        
                        # 시선 이탈 감지
                        _, distraction_status_message = check_distraction(frame, yaw, roll, time.time())
                        
                        # 휴대폰 사용 감지 (보는 행위 포함)
                        # MediaPipe 얼굴 랜드마크 정보가 필요하므로 이 조건 내에서 호출
                        _, phone_usage_status_message = check_phone_usage(frame, detected_objects, face_landmarks, time.time(), screen_width, screen_height, pitch, yaw)
                        
                        # 정보 표시 (EAR, Pitch, Yaw, Roll)
                        display_info_on_frame(frame, screen_width, avg_ear, pitch, yaw, roll)
            else: # 얼굴이 감지되지 않았을 때
                # 얼굴이 없으면 졸음/시선/휴대폰 사용 카운터 초기화
                COUNTER_DROWSY_EYE = 0
                COUNTER_GAZE_DEVIATION = 0
                COUNTER_PHONE_USAGE = 0


            # 화면 하단에 현재 상태 및 조작 가이드 표시
            cv2.putText(frame, f"ID Status: {identification_status}", (50, screen_height - 60), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)
            cv2.putText(frame, "Press 'R' to Register, 'I' to Identify, 'ESC' to Exit", (50, screen_height - 30), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 1)


            # 터미널에 상태 메시지 출력 (우선순위: 졸음 > 시선 이탈 > 휴대폰)
            if drowsiness_status_message:
                print(f"[{time.strftime('%H:%M:%S', time.localtime())}] {drowsiness_status_message}")
            elif distraction_status_message: 
                print(f"[{time.strftime('%H:%M:%S', time.localtime())}] {distraction_status_message}")
            elif phone_usage_status_message:
                print(f"[{time.strftime('%H:%M:%S', time.localtime())}] {phone_usage_status_message}")

            cv2.imshow('Driver Monitoring System', frame) # 화면에 프레임 표시

            # 키 입력 처리
            key = cv2.waitKey(5) & 0xFF
            if key == 27: # ESC key
                break
            elif key == ord('r'): # 'R' key for Registration
                print(f"Attempting to register face for '{user_to_register}'...")
                if register_driver_face(frame, user_to_register):
                    identification_status = f"Registered {user_to_register}"
                else:
                    identification_status = "Registration Failed"
            elif key == ord('i'): # 'I' key for Identification
                print("Attempting to identify driver...")
                identified_name = identify_driver(frame)
                identification_status = identified_name
                print(f"Identification Result: {identified_name}")

    # 자원 해제
    cap.release() 
    cv2.destroyAllWindows()

if __name__ == "__main__":
    run_driver_monitoring_system()