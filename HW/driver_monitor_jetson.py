import cv2
import numpy as np
import mediapipe as mp
import face_recognition
import json
import os
import time
import logging
import threading
import queue
import argparse
import subprocess
import sys
import uuid
import base64
from dataclasses import dataclass
from typing import Dict, List, Tuple, Optional
from ultralytics import YOLO
from PIL import Image, ImageDraw, ImageFont
import math
from scipy.spatial import distance as dist

# MQTT 클라이언트 추가
try:
    import paho.mqtt.client as mqtt
    MQTT_AVAILABLE = True
except ImportError:
    MQTT_AVAILABLE = False
    logging.warning("MQTT 라이브러리가 설치되지 않았습니다. pip install paho-mqtt")

# 로깅 설정 - UTF-8 인코딩 지원
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('driver_monitor.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)

# 전역 폰트 캐시
_korean_font_cache = {}

def put_korean_text(frame: np.ndarray, text: str, position: Tuple[int, int], 
                   font_size: int = 20, color: Tuple[int, int, int] = (255, 255, 255), 
                   thickness: int = 2) -> np.ndarray:
    """한글 텍스트를 OpenCV 프레임에 표시하는 함수 (폰트 캐시 적용)"""
    try:
        # 폰트 캐시 키
        font_key = f"{font_size}"
        
        # 캐시된 폰트가 있으면 사용
        if font_key in _korean_font_cache:
            font = _korean_font_cache[font_key]
        else:
            # PIL 이미지로 변환
            frame_pil = Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
            draw = ImageDraw.Draw(frame_pil)
            
            # 한글 폰트 로드 (캐시 적용)
            font = None
            font_paths = [
                # Windows 폰트들
                "C:/Windows/Fonts/malgun.ttf",
                "C:/Windows/Fonts/gulim.ttc",
                "C:/Windows/Fonts/batang.ttc",
                "malgun.ttf",
                "gulim.ttc",
                # macOS 폰트들
                "/System/Library/Fonts/AppleGothic.ttf",
                "/System/Library/Fonts/STHeiti Light.ttc",
                # Linux 폰트들
                "/usr/share/fonts/truetype/nanum/NanumGothic.ttf",
                "/usr/share/fonts/truetype/nanum/NanumBarunGothic.ttf",
                "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            ]
            
            for font_path in font_paths:
                try:
                    font = ImageFont.truetype(font_path, font_size)
                    # 캐시에 저장
                    _korean_font_cache[font_key] = font
                    logging.info(f"한글 폰트 로드 성공 (캐시됨): {font_path}")
                    break
                except Exception as e:
                    continue
            
            if font is None:
                # 폰트를 찾을 수 없으면 기본 폰트 사용
                font = ImageFont.load_default()
                _korean_font_cache[font_key] = font
                logging.warning("한글 폰트를 찾을 수 없어 기본 폰트 사용")
        
        # PIL 이미지로 변환
        frame_pil = Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
        draw = ImageDraw.Draw(frame_pil)
        
        # 텍스트 그리기
        draw.text(position, text, font=font, fill=color[::-1])  # RGB to BGR
        
        # OpenCV 이미지로 변환
        frame_result = cv2.cvtColor(np.array(frame_pil), cv2.COLOR_RGB2BGR)
        return frame_result
        
    except Exception as e:
        logging.warning(f"한글 텍스트 표시 실패, 영어로 대체: {e}")
        # 실패 시 영어로 표시
        cv2.putText(frame, text, position, cv2.FONT_HERSHEY_SIMPLEX, 
                   font_size/30, color, thickness)
        return frame

@dataclass
class PerformanceConfig:
    """성능 설정 클래스"""
    performance_mode: bool = True
    skip_frames: int = 2
    webcam_resolution: Tuple[int, int] = (640, 480)
    face_recognition_interval: int = 30
    yolo_detection_interval: int = 10
    enable_gpu: bool = False

@dataclass
class DetectionThresholds:
    """감지 임계치 클래스"""
    eye_ar_thresh: float = 0.20  # 0.25에서 0.20으로 더 관대하게 조정
    eye_ar_consec_frames: int = 3  # 4에서 3으로 더 빠르게 감지
    pitch_down_thresh: float = -8.0  # -12.0에서 -8.0으로 더 관대하게
    yaw_thresh: float = 25.0  # 30.0에서 25.0으로 더 관대하게
    roll_thresh: float = 10.0  # 12.0에서 10.0으로 더 관대하게
    gaze_consec_frames: int = 3  # 4에서 3으로 더 빠르게 감지
    phone_near_face_threshold_px: int = 0  # 고정 픽셀 사용 안함, 얼굴 크기 정규화 사용
    phone_consec_frames: int = 3  # 4에서 3으로 더 빠르게 감지
    gaze_to_phone_yaw_thresh: float = 25  # 30에서 25로 더 관대하게
    gaze_to_phone_pitch_thresh: float = -8  # -10에서 -8로 더 관대하게
    face_recognition_threshold: float = 0.45
    # 추가 설정값들
    phone_near_face_ratio: float = 0.60  # 얼굴 크기 대비 휴대폰 근접 비율
    warning_cooldown_ms: int = 200  # 300에서 200으로 더 빠르게
    danger_cooldown_ms: int = 300   # 500에서 300으로 더 빠르게
    yaw_phone_direction_correction: float = 1.0  # yaw 방향성 보정 (1.0 또는 -1.0)

@dataclass
class BaselineConfig:
    """베이스라인 설정 클래스"""
    duration_quick: int = 60
    duration_default: int = 300
    duration_full: int = 600

@dataclass
class PathConfig:
    """경로 설정 클래스"""
    data_dir: str = "./data"
    model_dir: str = "./models"
    face_db_path: str = "./data/registered_faces.json"
    baseline_path: str = "./data/baseline.json"
    thresholds_path: str = "./data/driver_thresholds.json"

@dataclass
class AutoSetupConfig:
    """자동 설정 클래스"""
    auto_baseline_measurement: bool = True
    baseline_duration: int = 300
    auto_face_registration: bool = True
    registration_duration: int = 60
    default_user_name: str = "DriverA"

@dataclass
class DisplayConfig:
    """화면 표시 설정 클래스"""
    use_english: bool = True
    show_landmarks: bool = True
    show_info_panel: bool = True

@dataclass
class AutomationConfig:
    """자동화 설정 클래스"""
    enable_automation: bool = True
    require_raspberry_pi_auth: bool = True
    enable_sms_notification: bool = True
    enable_app_notification: bool = True
    unknown_driver_timeout: int = 30  # 미인증 운전자 대기 시간 (초)
    auth_request_timeout: int = 60    # 라즈베리파이 인증 요청 타임아웃 (초)
    sms_phone_numbers: List[str] = None  # SMS 수신 번호 목록
    mqtt_broker_host: str = "192.168.10.3"
    mqtt_broker_port: int = 1883
    mqtt_username: str = "moring"
    mqtt_password: str = "kimoring"

@dataclass
class JetsonConfig:
    """Jetson 전용 설정 클래스"""
    camera_type: str = "usb"  # "usb" or "csi"
    enable_gpu_acceleration: bool = True
    power_mode: int = 2  # 0: 최대 성능, 2: 균형 모드
    enable_jetson_clocks: bool = True
    gpu_memory_fraction: float = 0.8
    tensorrt_optimization: bool = False

@dataclass
class ApprovalConfig:
    """승인 시스템 설정 클래스"""
    enable_approval_system: bool = True
    mqtt_broker: str = "192.168.10.3"
    mqtt_port: int = 1883
    mqtt_username: str = "moring"
    mqtt_password: str = "kimoring"
    mqtt_client_id: str = "jetson_driver_monitor"
    approval_timeout: int = 60  # 60초 타임아웃
    vin: str = "KNMK5C2HMLP000437"  # 차량 VIN

class ConfigManager:
    """설정 관리 클래스"""
    
    def __init__(self, config_file: str = "config.json"):
        self.config_file = config_file
        self.base_dir = os.path.dirname(os.path.abspath(__file__))
        
        # 기본 설정 초기화
        self.performance_config = PerformanceConfig()
        self.detection_thresholds = DetectionThresholds()
        self.baseline_config = BaselineConfig()
        self.path_config = PathConfig()
        self.auto_setup_config = AutoSetupConfig()
        self.display_config = DisplayConfig()
        self.jetson_config = JetsonConfig()
        self.approval_config = ApprovalConfig()
        
        # 설정 로드 후 경로 설정
        self.load_config()
        
        # 경로 생성
        os.makedirs(self.path_config.data_dir, exist_ok=True)
        os.makedirs(self.path_config.model_dir, exist_ok=True)
    
    def load_config(self):
        """설정 파일 로드"""
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r', encoding='utf-8') as f:
                    config_data = json.load(f)
                
                # 성능 설정 로드
                if 'performance' in config_data:
                    perf_data = config_data['performance']
                    self.performance_config = PerformanceConfig(
                        performance_mode=perf_data.get('performance_mode', True),
                        skip_frames=perf_data.get('skip_frames', 2),
                        webcam_resolution=tuple(perf_data.get('webcam_resolution', [640, 480])),
                        face_recognition_interval=perf_data.get('face_recognition_interval', 30),
                        yolo_detection_interval=perf_data.get('yolo_detection_interval', 10),
                        enable_gpu=perf_data.get('enable_gpu', False)
                    )
                
                # 감지 임계치 로드
                if 'detection_thresholds' in config_data:
                    thresh_data = config_data['detection_thresholds']
                    self.detection_thresholds = DetectionThresholds(
                        eye_ar_thresh=thresh_data.get('eye_ar_thresh', 0.20),
                        eye_ar_consec_frames=thresh_data.get('eye_ar_consec_frames', 3),
                        pitch_down_thresh=thresh_data.get('pitch_down_thresh', -8.0),
                        yaw_thresh=thresh_data.get('yaw_thresh', 25.0),
                        roll_thresh=thresh_data.get('roll_thresh', 10.0),
                        gaze_consec_frames=thresh_data.get('gaze_consec_frames', 3),
                        phone_near_face_threshold_px=thresh_data.get('phone_near_face_threshold_px', 0),
                        phone_consec_frames=thresh_data.get('phone_consec_frames', 3),
                        gaze_to_phone_yaw_thresh=thresh_data.get('gaze_to_phone_yaw_thresh', 25),
                        gaze_to_phone_pitch_thresh=thresh_data.get('gaze_to_phone_pitch_thresh', -8),
                        face_recognition_threshold=thresh_data.get('face_recognition_threshold', 0.45),
                        phone_near_face_ratio=thresh_data.get('phone_near_face_ratio', 0.60),
                        warning_cooldown_ms=thresh_data.get('warning_cooldown_ms', 200),
                        danger_cooldown_ms=thresh_data.get('danger_cooldown_ms', 300),
                        yaw_phone_direction_correction=thresh_data.get('yaw_phone_direction_correction', 1.0)
                    )
                
                # 경로 설정 로드
                if 'paths' in config_data:
                    path_data = config_data['paths']
                    self.path_config = PathConfig(
                        data_dir=path_data.get('data_dir', './data'),
                        model_dir=path_data.get('model_dir', './models'),
                        face_db_path=path_data.get('face_db_path', './data/registered_faces.json'),
                        baseline_path=path_data.get('baseline_path', './data/baseline.json'),
                        thresholds_path=path_data.get('thresholds_path', './data/driver_thresholds.json')
                    )
                
                # 자동 설정 로드
                if 'auto_setup' in config_data:
                    auto_data = config_data['auto_setup']
                    self.auto_setup_config = AutoSetupConfig(
                        auto_baseline_measurement=auto_data.get('auto_baseline_measurement', True),
                        baseline_duration=auto_data.get('baseline_duration', 300),
                        auto_face_registration=auto_data.get('auto_face_registration', True),
                        registration_duration=auto_data.get('registration_duration', 60),
                        default_user_name=auto_data.get('default_user_name', 'DriverA')
                    )
                
                # 화면 표시 설정 로드
                if 'display' in config_data:
                    display_data = config_data['display']
                    self.display_config = DisplayConfig(
                        use_english=display_data.get('use_english', True),
                        show_landmarks=display_data.get('show_landmarks', True),
                        show_info_panel=display_data.get('show_info_panel', True)
                    )
                
                # Jetson 설정 로드
                if 'jetson' in config_data:
                    jetson_data = config_data['jetson']
                    self.jetson_config = JetsonConfig(
                        camera_type=jetson_data.get('camera_type', 'usb'),
                        enable_gpu_acceleration=jetson_data.get('enable_gpu_acceleration', True),
                        power_mode=jetson_data.get('power_mode', 2),
                        enable_jetson_clocks=jetson_data.get('enable_jetson_clocks', True),
                        gpu_memory_fraction=jetson_data.get('gpu_memory_fraction', 0.8),
                        tensorrt_optimization=jetson_data.get('tensorrt_optimization', False)
                    )
                
                # 승인 시스템 설정 로드
                if 'approval' in config_data:
                    approval_data = config_data['approval']
                    self.approval_config = ApprovalConfig(
                        enable_approval_system=approval_data.get('enable_approval_system', True),
                        mqtt_broker=approval_data.get('mqtt_broker', '192.168.10.3'),
                        mqtt_port=approval_data.get('mqtt_port', 1883),
                        mqtt_username=approval_data.get('mqtt_username', 'moring'),
                        mqtt_password=approval_data.get('mqtt_password', 'kimoring'),
                        mqtt_client_id=approval_data.get('mqtt_client_id', 'jetson_driver_monitor'),
                        approval_timeout=approval_data.get('approval_timeout', 60),
                        vin=approval_data.get('vin', 'KNMK5C2HMLP000437')
                    )
                
                logging.info("설정 파일 로드 완료")
            else:
                self.save_default_config()
                logging.info("기본 설정 파일 생성 완료")
                
        except Exception as e:
            logging.error(f"설정 파일 로드 실패: {e}")
            self.save_default_config()
    
    def save_config(self):
        """설정 파일 저장 - 원자적 저장으로 파일 손상 방지"""
        try:
            config_data = {
                'performance': {
                    'performance_mode': self.performance_config.performance_mode,
                    'skip_frames': self.performance_config.skip_frames,
                    'webcam_resolution': list(self.performance_config.webcam_resolution),
                    'face_recognition_interval': self.performance_config.face_recognition_interval,
                    'yolo_detection_interval': self.performance_config.yolo_detection_interval,
                    'enable_gpu': self.performance_config.enable_gpu
                },
                'detection_thresholds': {
                    'eye_ar_thresh': self.detection_thresholds.eye_ar_thresh,
                    'eye_ar_consec_frames': self.detection_thresholds.eye_ar_consec_frames,
                    'pitch_down_thresh': self.detection_thresholds.pitch_down_thresh,
                    'yaw_thresh': self.detection_thresholds.yaw_thresh,
                    'roll_thresh': self.detection_thresholds.roll_thresh,
                    'gaze_consec_frames': self.detection_thresholds.gaze_consec_frames,
                    'phone_near_face_threshold_px': self.detection_thresholds.phone_near_face_threshold_px,
                    'phone_consec_frames': self.detection_thresholds.phone_consec_frames,
                    'gaze_to_phone_yaw_thresh': self.detection_thresholds.gaze_to_phone_yaw_thresh,
                    'gaze_to_phone_pitch_thresh': self.detection_thresholds.gaze_to_phone_pitch_thresh,
                    'face_recognition_threshold': self.detection_thresholds.face_recognition_threshold,
                    'phone_near_face_ratio': self.detection_thresholds.phone_near_face_ratio,
                    'warning_cooldown_ms': self.detection_thresholds.warning_cooldown_ms,
                    'danger_cooldown_ms': self.detection_thresholds.danger_cooldown_ms,
                    'yaw_phone_direction_correction': self.detection_thresholds.yaw_phone_direction_correction
                },
                'baseline_config': {
                    'duration_quick': self.baseline_config.duration_quick,
                    'duration_default': self.baseline_config.duration_default,
                    'duration_full': self.baseline_config.duration_full
                },
                'paths': {
                    'data_dir': self.path_config.data_dir,
                    'model_dir': self.path_config.model_dir,
                    'face_db_path': self.path_config.face_db_path,
                    'baseline_path': self.path_config.baseline_path,
                    'thresholds_path': self.path_config.thresholds_path
                },
                'auto_setup': {
                    'auto_baseline_measurement': self.auto_setup_config.auto_baseline_measurement,
                    'baseline_duration': self.auto_setup_config.baseline_duration,
                    'auto_face_registration': self.auto_setup_config.auto_face_registration,
                    'registration_duration': self.auto_setup_config.registration_duration,
                    'default_user_name': self.auto_setup_config.default_user_name
                },
                'display': {
                    'use_english': self.display_config.use_english,
                    'show_landmarks': self.display_config.show_landmarks,
                    'show_info_panel': self.display_config.show_info_panel
                },
                'jetson': {
                    'camera_type': self.jetson_config.camera_type,
                    'enable_gpu_acceleration': self.jetson_config.enable_gpu_acceleration,
                    'power_mode': self.jetson_config.power_mode,
                    'enable_jetson_clocks': self.jetson_config.enable_jetson_clocks,
                    'gpu_memory_fraction': self.jetson_config.gpu_memory_fraction,
                    'tensorrt_optimization': self.jetson_config.tensorrt_optimization
                }
            }
            
            # 8. Log/Config Protection - 원자적 저장
            temp_file = f"{self.config_file}.tmp"
            with open(temp_file, 'w', encoding='utf-8') as f:
                json.dump(config_data, f, indent=4, ensure_ascii=False)
            
            # 임시 파일을 실제 파일로 교체 (원자적 작업)
            if os.path.exists(self.config_file):
                os.replace(temp_file, self.config_file)
            else:
                os.rename(temp_file, self.config_file)
            
            logging.info("설정 파일 저장 완료")
            
        except Exception as e:
            logging.error(f"설정 파일 저장 실패: {e}")
            # 임시 파일 정리
            if os.path.exists(temp_file):
                try:
                    os.remove(temp_file)
                except:
                    pass
    
    def save_default_config(self):
        """기본 설정 파일 생성"""
        self.save_config()

class PerformanceMonitor:
    """성능 모니터링 클래스"""
    
    def __init__(self):
        self.fps_counter = 0
        self.fps_start_time = time.time()
        self.current_fps = 0.0
        self.frame_times = []
        self.max_frame_times = 100
        
    def update_fps(self):
        """FPS 업데이트"""
        self.fps_counter += 1
        current_time = time.time()
        
        if current_time - self.fps_start_time >= 1.0:
            self.current_fps = self.fps_counter / (current_time - self.fps_start_time)
            self.fps_counter = 0
            self.fps_start_time = current_time
    
    def add_frame_time(self, frame_time: float):
        """프레임 처리 시간 기록"""
        self.frame_times.append(frame_time)
        if len(self.frame_times) > self.max_frame_times:
            self.frame_times.pop(0)
    
    def get_avg_frame_time(self) -> float:
        """평균 프레임 처리 시간 반환"""
        if not self.frame_times:
            return 0.0
        return sum(self.frame_times) / len(self.frame_times)
    
    def get_performance_info(self) -> Dict[str, float]:
        """성능 정보 반환"""
        return {
            'fps': self.current_fps,
            'avg_frame_time': self.get_avg_frame_time(),
            'min_frame_time': min(self.frame_times) if self.frame_times else 0.0,
            'max_frame_time': max(self.frame_times) if self.frame_times else 0.0
        }

class FaceProcessor:
    """얼굴 처리 클래스"""
    
    def __init__(self, config: ConfigManager):
        self.config = config
        self.mp_face_mesh = mp.solutions.face_mesh
        self.mp_drawing = mp.solutions.drawing_utils
        self.mp_drawing_styles = mp.solutions.drawing_styles
        
        # MediaPipe Face Mesh 초기화
        self.face_mesh = self.mp_face_mesh.FaceMesh(
            max_num_faces=1,
            refine_landmarks=True,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5
        )
        
        # 얼굴 랜드마크 인덱스
        self.LEFT_EYE_LANDMARKS = [33, 160, 158, 133, 153, 144]
        self.RIGHT_EYE_LANDMARKS = [362, 385, 387, 373, 380, 374]
        
        # 캐시된 얼굴 데이터
        self.cached_faces = None
        self.face_cache_timestamp = 0
        
        logging.info("FaceProcessor 초기화 완료")
    
    def calculate_ear(self, eye_landmarks: List[Tuple[int, int]]) -> float:
        """EAR (Eye Aspect Ratio) 계산"""
        try:
            A = dist.euclidean(eye_landmarks[1], eye_landmarks[5])
            B = dist.euclidean(eye_landmarks[2], eye_landmarks[4])
            C = dist.euclidean(eye_landmarks[0], eye_landmarks[3])
            ear = (A + B) / (2.0 * C)
            return ear
        except Exception as e:
            logging.error(f"EAR 계산 실패: {e}")
            return 0.0
    
    def estimate_head_pose(self, face_landmarks, image_shape: Tuple[int, int, int]) -> Tuple[Optional[float], Optional[float], Optional[float]]:
        """고개 자세 추정"""
        try:
            img_h, img_w, _ = image_shape
            
            # 3D 모델 포인트
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

            # 2D 이미지 포인트
            image_points = np.array([
                (face_landmarks.landmark[1].x * img_w, face_landmarks.landmark[1].y * img_h),
                (face_landmarks.landmark[152].x * img_w, face_landmarks.landmark[152].y * img_h),
                (face_landmarks.landmark[33].x * img_w, face_landmarks.landmark[33].y * img_h),
                (face_landmarks.landmark[263].x * img_w, face_landmarks.landmark[263].y * img_h),
                (face_landmarks.landmark[61].x * img_w, face_landmarks.landmark[61].y * img_h),
                (face_landmarks.landmark[291].x * img_w, face_landmarks.landmark[291].y * img_h)
            ], dtype="double")

            # 카메라 매트릭스
            focal_length = 1 * img_w
            center = (img_w / 2, img_h / 2)
            camera_matrix = np.array(
                [[focal_length, 0, center[0]],
                 [0, focal_length, center[1]],
                 [0, 0, 1]], dtype="double"
            )

            dist_coeffs = np.zeros((4, 1))

            # PnP 알고리즘
            success, rotation_vector, translation_vector = cv2.solvePnP(
                model_points, image_points, camera_matrix, dist_coeffs, flags=cv2.SOLVEPNP_ITERATIVE
            )

            if not success:
                return None, None, None

            # 회전 벡터를 회전 행렬로 변환
            rmat, _ = cv2.Rodrigues(rotation_vector)
            
            # 오일러 각 추출
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
            
        except Exception as e:
            logging.error(f"고개 자세 추정 실패: {e}")
            return None, None, None
    
    def process_face(self, frame: np.ndarray) -> Dict[str, any]:
        """얼굴 처리 및 랜드마크 추출"""
        try:
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            frame_rgb.flags.writeable = False
            results = self.face_mesh.process(frame_rgb)
            frame_rgb.flags.writeable = True
            
            if not results.multi_face_landmarks:
                return {
                    'success': False,
                    'ear': 0.0,
                    'pitch': None,
                    'yaw': None,
                    'roll': None,
                    'landmarks': None
                }
            
            face_landmarks = results.multi_face_landmarks[0]
            img_h, img_w = frame.shape[:2]
            
            # 눈 랜드마크 추출
            left_eye_points = [(int(face_landmarks.landmark[i].x * img_w), 
                               int(face_landmarks.landmark[i].y * img_h)) 
                              for i in self.LEFT_EYE_LANDMARKS]
            right_eye_points = [(int(face_landmarks.landmark[i].x * img_w), 
                                int(face_landmarks.landmark[i].y * img_h)) 
                               for i in self.RIGHT_EYE_LANDMARKS]
            
            # EAR 계산
            left_ear = self.calculate_ear(left_eye_points)
            right_ear = self.calculate_ear(right_eye_points)
            avg_ear = (left_ear + right_ear) / 2.0
            
            # 고개 자세 추정
            pitch, yaw, roll = self.estimate_head_pose(face_landmarks, frame.shape)
            
            return {
                'success': True,
                'ear': avg_ear,
                'pitch': pitch,
                'yaw': yaw,
                'roll': roll,
                'landmarks': face_landmarks
            }
            
        except Exception as e:
            logging.error(f"얼굴 처리 실패: {e}")
            return {
                'success': False,
                'ear': 0.0,
                'pitch': None,
                'yaw': None,
                'roll': None,
                'landmarks': None
            }
    
    def load_registered_faces(self) -> Dict[str, np.ndarray]:
        """등록된 얼굴 데이터 로드 (캐시 적용)"""
        try:
            current_time = time.time()
            
            # 캐시가 유효한지 확인 (5초마다 갱신)
            if (self.cached_faces is not None and 
                (current_time - self.face_cache_timestamp) < 5):
                return self.cached_faces
            
            face_db_path = os.path.join(self.config.path_config.data_dir, "registered_faces.json")
            
            if os.path.exists(face_db_path):
                with open(face_db_path, 'r') as f:
                    data = json.load(f)
                
                loaded_faces = {}
                for name, emb in data.items():
                    try:
                        if isinstance(emb, list):
                            # 리스트의 각 요소가 128차원 벡터인지 확인
                            if len(emb) > 0 and isinstance(emb[0], list) and len(emb[0]) == 128:
                                # 다중 각도 등록된 경우
                                loaded_faces[name] = [np.array(e, dtype=np.float64) for e in emb]
                            else:
                                # 단일 등록된 경우
                                loaded_faces[name] = np.array(emb, dtype=np.float64)
                        else:
                            loaded_faces[name] = np.array(emb, dtype=np.float64)
                    except Exception as e:
                        logging.warning(f"얼굴 데이터 로드 실패 ({name}): {e}")
                        continue
                
                # 캐시 업데이트
                self.cached_faces = loaded_faces
                self.face_cache_timestamp = current_time
                
                if loaded_faces:
                    logging.info(f"얼굴 데이터 로드 완료: {len(loaded_faces)}개 (캐시됨)")
                
                return loaded_faces
            else:
                logging.info("등록된 얼굴 데이터베이스가 없습니다")
                
        except Exception as e:
            logging.error(f"얼굴 데이터 로드 실패: {e}")
        
        self.cached_faces = {}
        self.face_cache_timestamp = current_time
        return {}
    
    def identify_driver(self, frame: np.ndarray) -> str:
        """운전자 식별 (엄격한 인식)"""
        try:
            face_locations = face_recognition.face_locations(frame)
            if not face_locations:
                return "No Face"
            
            if len(face_locations) > 1:
                return "Multiple Faces"

            encodings = face_recognition.face_encodings(frame, face_locations)
            if not encodings:
                return "Encoding Failed"
            
            current_face_encoding = encodings[0]
            registered_faces = self.load_registered_faces()
            
            if not registered_faces:
                return "No Registered"

            # 등록된 얼굴들과 비교
            best_match_name = None
            best_match_distance = float('inf')
            
            for name, registered_encodings in registered_faces.items():
                try:
                    if isinstance(registered_encodings, list):
                        # 다중 각도 등록된 경우
                        distances = face_recognition.face_distance(registered_encodings, current_face_encoding)
                        min_distance = float(np.min(distances))
                    else:
                        # 단일 등록된 경우
                        distances = face_recognition.face_distance([registered_encodings], current_face_encoding)
                        min_distance = float(distances[0])
                    
                    if min_distance < best_match_distance:
                        best_match_distance = min_distance
                        best_match_name = name
                        
                except Exception as e:
                    logging.warning(f"얼굴 비교 실패 ({name}): {e}")
                    continue
            
            # 엄격한 임계값 설정
            STRICT_THRESHOLD = 0.45  # 엄격 (0.35에서 0.45로 완화)
            NORMAL_THRESHOLD = 0.55  # 일반 임계값 (0.45에서 0.55로 완화)
            
            confidence = (1 - best_match_distance) * 100
            
            if best_match_distance < STRICT_THRESHOLD:
                # 매우 확실한 매치
                logging.info(f"운전자 식별 (엄격): {best_match_name} (거리: {best_match_distance:.3f}, 신뢰도: {confidence:.1f}%)")
                return best_match_name
            elif best_match_distance < NORMAL_THRESHOLD:
                # 의심스러운 매치 - 추가 확인 필요
                logging.warning(f"불확실한 매치: {best_match_name} (거리: {best_match_distance:.3f}, 신뢰도: {confidence:.1f}%)")
                return "Uncertain"
            else:
                # 매치 실패
                logging.info(f"알 수 없는 운전자 (최소 거리: {best_match_distance:.3f})")
                return "Unknown Driver"
                
        except Exception as e:
            logging.error(f"운전자 식별 실패: {e}")
            return "Identification Error"
    
    def register_driver_face(self, frame: np.ndarray, user_name: str) -> bool:
        """운전자 얼굴 등록 (다중 각도 지원)"""
        try:
            face_locations = face_recognition.face_locations(frame)
            if not face_locations:
                logging.warning("등록 실패: 얼굴이 감지되지 않음")
                return False
            
            if len(face_locations) > 1:
                logging.warning("등록 실패: 여러 얼굴이 감지됨")
                return False

            encodings = face_recognition.face_encodings(frame, face_locations)
            if not encodings:
                logging.warning("등록 실패: 얼굴 인코딩 실패")
                return False
            
            current_face_encoding = encodings[0]
            
            # 기존 등록된 얼굴 데이터 불러오기
            registered_faces = self.load_registered_faces()
            
            # 다중 각도 등록을 위한 키 생성
            base_key = user_name
            if base_key not in registered_faces:
                registered_faces[base_key] = []  # 리스트로 초기화
            
            # 기존 등록된 얼굴이 단일 인코딩이면 리스트로 변환
            if not isinstance(registered_faces[base_key], list):
                registered_faces[base_key] = [registered_faces[base_key]]
            
            # 새로운 인코딩 추가
            registered_faces[base_key].append(current_face_encoding)
            
            # 최대 개수 제한 (메모리 효율성) - 3개 각도
            angle_count = 3
            if len(registered_faces[base_key]) > angle_count:
                registered_faces[base_key] = registered_faces[base_key][-angle_count:]

            # 파일에 저장
            face_db_path = os.path.join(self.config.path_config.data_dir, "registered_faces.json")
            serializable_faces = {}
            for name, encodings in registered_faces.items():
                if isinstance(encodings, list):
                    serializable_faces[name] = [emb.tolist() for emb in encodings]
                else:
                    serializable_faces[name] = encodings.tolist()
            
            with open(face_db_path, 'w') as f:
                json.dump(serializable_faces, f, indent=4)
            
            # 캐시 무효화
            self.cached_faces = None
            
            logging.info(f"운전자 '{user_name}' 다중 각도 등록 완료: {len(registered_faces[base_key])}/{angle_count}")
            return True
            
        except Exception as e:
            logging.error(f"운전자 등록 실패: {e}")
            return False
    
    def __del__(self):
        """소멸자"""
        if hasattr(self, 'face_mesh'):
            self.face_mesh.close()

class YOLODetector:
    """YOLO 객체 감지 클래스 (비동기 처리)"""
    
    def __init__(self, config: ConfigManager):
        self.config = config
        self.model_path = os.path.join(config.path_config.model_dir, "best.pt")
        self.model = None
        self.detection_queue = queue.Queue(maxsize=10)
        self.result_queue = queue.Queue(maxsize=10)
        self.detection_thread = None
        self.running = False
        
        self.load_model()
        self.start_detection_thread()
        
        logging.info("YOLODetector 초기화 완료")
    
    def load_model(self):
        """YOLO 모델 로드"""
        try:
            if not os.path.exists(self.model_path):
                raise FileNotFoundError(f"YOLO 모델 파일을 찾을 수 없습니다: {self.model_path}")
            
            self.model = YOLO(self.model_path)
            
            # GPU 사용 설정 (Jetson에서 강제 GPU 사용)
            try:
                self.model.to('cuda')
                logging.info("YOLO 모델을 GPU에서 실행합니다")
            except Exception as e:
                logging.warning(f"GPU 사용 실패, CPU로 전환: {e}")
                self.model.to('cpu')
                logging.info("YOLO 모델을 CPU에서 실행합니다")
                
        except Exception as e:
            logging.error(f"YOLO 모델 로드 실패: {e}")
            self.model = None
    
    def start_detection_thread(self):
        """감지 스레드 시작"""
        if self.model is None:
            return
        
        self.running = True
        self.detection_thread = threading.Thread(target=self._detection_worker, daemon=True)
        self.detection_thread.start()
        logging.info("YOLO 감지 스레드 시작")
    
    def _detection_worker(self):
        """감지 워커 스레드"""
        while self.running:
            try:
                # 프레임 대기 (최대 1초)
                try:
                    frame_data = self.detection_queue.get(timeout=1.0)
                except queue.Empty:
                    continue
                
                frame, frame_id = frame_data
                
                # YOLO 감지 실행
                results = self.model(frame, verbose=False)
                
                detected_objects = []
                H, W = frame.shape[:2]
                min_area = 0.01 * (W * H)  # 화면의 1% 미만 박스 무시
                
                for r in results:
                    boxes = r.boxes
                    for box in boxes:
                        class_id = int(box.cls)
                        class_name = self.model.names[class_id]
                        conf = float(box.conf)
                        
                        if class_name == 'device' and conf > 0.6:  # 신뢰도 임계값 증가
                            x1, y1, x2, y2 = map(int, box.xyxy[0])
                            area = max(0, (x2 - x1)) * max(0, (y2 - y1))
                            
                            if area >= min_area:  # 면적 필터 적용
                                detected_objects.append({
                                    'class': class_name,
                                    'bbox': [x1, y1, x2, y2],
                                    'conf': conf
                                })
                
                # 결과 큐에 저장
                try:
                    self.result_queue.put((frame_id, detected_objects), timeout=0.1)
                except queue.Full:
                    # 큐가 가득 찬 경우 가장 오래된 결과 제거
                    try:
                        self.result_queue.get_nowait()
                        self.result_queue.put((frame_id, detected_objects), timeout=0.1)
                    except:
                        pass
                        
            except Exception as e:
                logging.error(f"YOLO 감지 워커 오류: {e}")
                continue
    
    def detect_objects(self, frame: np.ndarray, frame_id: int) -> List[Dict]:
        """객체 감지 요청 (비동기)"""
        if self.model is None:
            return []
        
        try:
            # 감지 요청을 큐에 추가
            self.detection_queue.put((frame, frame_id), timeout=0.1)
        except queue.Full:
            # 큐가 가득 찬 경우 가장 오래된 요청 제거
            try:
                self.detection_queue.get_nowait()
                self.detection_queue.put((frame, frame_id), timeout=0.1)
            except:
                pass
        
        # 3. YOLO Result Matching 완화 - 가장 최신 결과 채택
        detected_objects = []
        latest_result = None
        
        while not self.result_queue.empty():
            try:
                result_frame_id, objects = self.result_queue.get_nowait()
                if latest_result is None or result_frame_id >= latest_result[0]:
                    latest_result = (result_frame_id, objects)
            except queue.Empty:
                break
        
        if latest_result is not None:
            detected_objects = latest_result[1]
        
        return detected_objects
    
    def stop(self):
        """감지 스레드 중지"""
        self.running = False
        if self.detection_thread and self.detection_thread.is_alive():
            self.detection_thread.join(timeout=2.0)
        logging.info("YOLO 감지 스레드 중지")

class DetectionManager:
    """감지 관리 클래스"""
    
    def __init__(self, config: ConfigManager):
        self.config = config
        self.counters = {
            'drowsy_eye': 0,
            'gaze_deviation': 0,
            'phone_usage': 0,
            'eyes_closed': 0,  # 신설: 눈 감김 카운터
            'head_down': 0     # 신설: 고개 떨굼 카운터
        }
        self.last_times = {
            'drowsy': 0,
            'gaze': 0,
            'phone': 0
        }
        self.warning_cooldown = 2.0
        
        logging.info("DetectionManager 초기화 완료")
    
    def check_drowsiness(self, frame: np.ndarray, ear: float, pitch: float, current_time: float, baseline: dict = None) -> Tuple[bool, str]:
        """졸음 감지 - 개인화된 baseline 기반 감지"""
        try:
            drowsiness_detected = False
            terminal_message = ""
            
            # 개인화된 임계값 계산
            if baseline and baseline.get("BASELINE_EYE_AR") is not None:
                eye_threshold = baseline["BASELINE_EYE_AR"] * 0.6  # 기본값 사용
                pitch_threshold = baseline["BASELINE_PITCH"] * 2.0  # 기본값 사용
            else:
                # baseline이 없으면 기본값 사용
                eye_threshold = self.config.detection_thresholds.eye_ar_thresh
                pitch_threshold = self.config.detection_thresholds.pitch_down_thresh
            
            # 눈 감김 조건 (개인화된 임계값)
            is_eyes_closed = (ear < eye_threshold)
            # 고개 떨굼 조건 (개인화된 임계값)
            is_head_down = (pitch is not None) and (pitch < pitch_threshold)
            
            # 추가 조건: 눈이 완전히 감겼는지 확인 (EAR이 매우 낮을 때만)
            is_eyes_very_closed = (ear < eye_threshold * 0.8)  # 20% 더 낮을 때
            
            # 개별 카운터 업데이트
            if is_eyes_closed:
                self.counters['eyes_closed'] += 1
            else:
                self.counters['eyes_closed'] = 0
                
            if is_head_down:
                self.counters['head_down'] += 1
            else:
                self.counters['head_down'] = 0
            
            # 개별 상태 표시 (영어)
            if is_eyes_closed:
                cv2.putText(frame, "EYES CLOSED!", (50, 80), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 165, 255), 2)
            if is_head_down:
                cv2.putText(frame, "HEAD DOWN!", (50, 120), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 165, 255), 2)
            
            # 졸음 판단: 더 관대한 조건
            if is_eyes_very_closed and is_head_down:
                self.counters['drowsy_eye'] += 1
            elif is_eyes_closed and is_head_down:
                # 일반적인 눈 감김 + 고개 떨굼
                self.counters['drowsy_eye'] += 0.8
            elif is_eyes_closed or is_head_down:
                # 하나라도 감지되면 카운터 증가
                self.counters['drowsy_eye'] += 0.3
            else:
                self.counters['drowsy_eye'] = 0
            
            if self.counters['drowsy_eye'] >= 5:  # 10프레임에서 5프레임으로 단축
                drowsiness_detected = True
                if current_time - self.last_times['drowsy'] > self.warning_cooldown:
                    # 큰 경고 표시 (영어)
                    cv2.putText(frame, "DROWSINESS DETECTED!", (50, 50), cv2.FONT_HERSHEY_SIMPLEX, 1.5, (0, 0, 255), 3)
                    cv2.putText(frame, "WAKE UP!", (50, 100), cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0, 0, 255), 2)
                    cv2.putText(frame, "EYES CLOSED + HEAD DOWN", (50, 150), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2)
                    terminal_message = f"DROWSINESS DETECTED: EAR({ear:.3f})(<{eye_threshold:.3f}), Pitch({pitch:.1f})(<{pitch_threshold:.1f})"
                    self.last_times['drowsy'] = current_time
            
            return drowsiness_detected, terminal_message
            
        except Exception as e:
            logging.error(f"졸음 감지 실패: {e}")
            return False, ""
    
    def check_distraction(self, frame: np.ndarray, yaw: float, roll: float, current_time: float, baseline: dict = None) -> Tuple[bool, str]:
        """시선 이탈 감지 - 개인화된 baseline 기반 감지"""
        try:
            gaze_deviation_detected = False
            terminal_message = ""
            
            # 개인화된 임계값 계산
            if baseline and baseline.get("BASELINE_YAW") is not None:
                yaw_threshold = baseline["BASELINE_YAW"] * 3.0  # 기본값 사용
                roll_threshold = baseline["BASELINE_ROLL"] * 2.0  # 기본값 사용
            else:
                # baseline이 없으면 기본값 사용
                yaw_threshold = self.config.detection_thresholds.yaw_thresh
                roll_threshold = self.config.detection_thresholds.roll_thresh
            
            # 더 엄격한 조건: Yaw와 Roll이 모두 임계값을 초과할 때만
            yaw_deviation = abs(yaw) > yaw_threshold
            roll_deviation = abs(roll) > roll_threshold
            
            # 개별 상태 표시
            if yaw_deviation:
                cv2.putText(frame, "HEAD TURN!", (50, 160), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 255), 2)
            if roll_deviation:
                cv2.putText(frame, "HEAD TILT!", (50, 200), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 255), 2)
            
            # 둘 다 벗어났을 때만 카운터 증가 (스트레칭 등 일시적인 움직임 무시)
            if yaw_deviation and roll_deviation:
                self.counters['gaze_deviation'] += 1
            elif yaw_deviation or roll_deviation:
                # 하나만 벗어났을 때는 카운터를 절반만 증가
                self.counters['gaze_deviation'] += 0.5
            else:
                self.counters['gaze_deviation'] = 0
            
            if self.counters['gaze_deviation'] >= 10:  # 10프레임 연속
                gaze_deviation_detected = True
                if current_time - self.last_times['gaze'] > self.warning_cooldown:
                    cv2.putText(frame, "DISTRACTION!", (50, 150), cv2.FONT_HERSHEY_SIMPLEX, 1.5, (0, 255, 255), 2)
                    cv2.putText(frame, "LOOK FORWARD!", (50, 190), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 255), 2)
                    terminal_message = f"DISTRACTION DETECTED: Yaw({yaw:.1f})(>{yaw_threshold:.1f}), Roll({roll:.1f})(>{roll_threshold:.1f})"
                    self.last_times['gaze'] = current_time
            
            return gaze_deviation_detected, terminal_message
            
        except Exception as e:
            logging.error(f"시선 이탈 감지 실패: {e}")
            return False, ""
    
    def check_phone_usage(self, frame: np.ndarray, detected_objects: List[Dict], 
                         face_landmarks, current_time: float, screen_width: int, 
                         screen_height: int, pitch: float, yaw: float) -> Tuple[bool, str]:
        """휴대폰 사용 감지"""
        try:
            phone_usage_detected = False
            terminal_message = ""
            phone_detected_in_frame = False
            
            if face_landmarks:
                # 얼굴 랜드마크 좌표
                nose_tip_x = int(face_landmarks.landmark[1].x * screen_width)
                nose_tip_y = int(face_landmarks.landmark[1].y * screen_height)
                left_ear_x = int(face_landmarks.landmark[132].x * screen_width)
                left_ear_y = int(face_landmarks.landmark[132].y * screen_height)
                right_ear_x = int(face_landmarks.landmark[361].x * screen_width)
                right_ear_y = int(face_landmarks.landmark[361].y * screen_height)
                mouth_x = int(face_landmarks.landmark[13].x * screen_width)
                mouth_y = int(face_landmarks.landmark[13].y * screen_height)
                
                # 얼굴 크기 정규화: 눈꼬리 간 거리로 얼굴 스케일 산출 (33 ↔ 263)
                lx, ly = int(face_landmarks.landmark[33].x * screen_width), int(face_landmarks.landmark[33].y * screen_height)
                rx, ry = int(face_landmarks.landmark[263].x * screen_width), int(face_landmarks.landmark[263].y * screen_height)
                d_face = max(1.0, dist.euclidean((lx, ly), (rx, ry)))
                near_thresh = self.config.detection_thresholds.phone_near_face_ratio * d_face  # 설정값 사용
                
                # 4. Multiple Phone Boxes 처리 - 가장 위험한 박스 선택
                most_dangerous_phone = None
                min_distance = float('inf')
                
                for obj in detected_objects:
                    if obj['class'] == 'device':
                        phone_detected_in_frame = True
                        bbox = obj['bbox']
                        phone_center_x = (bbox[0] + bbox[2]) // 2
                        phone_center_y = (bbox[1] + bbox[3]) // 2
                        
                        cv2.rectangle(frame, (bbox[0], bbox[1]), (bbox[2], bbox[3]), (0, 255, 0), 2)
                        cv2.putText(frame, "Device", (bbox[0], bbox[1] - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)
                        
                        # 통화 감지 (얼굴 크기 정규화 적용)
                        dist_to_left_ear = dist.euclidean((phone_center_x, phone_center_y), (left_ear_x, left_ear_y))
                        dist_to_right_ear = dist.euclidean((phone_center_x, phone_center_y), (right_ear_x, right_ear_y))
                        dist_to_mouth = dist.euclidean((phone_center_x, phone_center_y), (mouth_x, mouth_y))
                        
                        # 가장 가까운 거리 계산
                        min_dist_to_face = min(dist_to_left_ear, dist_to_right_ear, dist_to_mouth)
                        
                        # 가장 위험한 휴대폰 선택 (가장 가까운 것)
                        if min_dist_to_face < min_distance:
                            min_distance = min_dist_to_face
                            most_dangerous_phone = {
                                'bbox': bbox,
                                'center_x': phone_center_x,
                                'center_y': phone_center_y,
                                'dist_to_left_ear': dist_to_left_ear,
                                'dist_to_right_ear': dist_to_right_ear,
                                'dist_to_mouth': dist_to_mouth
                            }
                
                # 가장 위험한 휴대폰에 대해서만 판단
                if most_dangerous_phone:
                    is_phone_near_face = (most_dangerous_phone['dist_to_left_ear'] < near_thresh or
                                         most_dangerous_phone['dist_to_right_ear'] < near_thresh or
                                         most_dangerous_phone['dist_to_mouth'] < near_thresh)
                    
                    # 시선 분산 감지 (yaw 방향성 보정 적용)
                    is_gazing_at_phone = False
                    corrected_yaw = yaw * self.config.detection_thresholds.yaw_phone_direction_correction
                    if most_dangerous_phone['center_x'] < nose_tip_x and corrected_yaw > self.config.detection_thresholds.gaze_to_phone_yaw_thresh:
                        is_gazing_at_phone = True
                    elif most_dangerous_phone['center_x'] > nose_tip_x and corrected_yaw < -self.config.detection_thresholds.gaze_to_phone_yaw_thresh:
                        is_gazing_at_phone = True
                    elif most_dangerous_phone['center_y'] > nose_tip_y and pitch < self.config.detection_thresholds.gaze_to_phone_pitch_thresh:
                        is_gazing_at_phone = True
                    
                    # 휴대폰 사용 판단
                    if is_phone_near_face or is_gazing_at_phone:
                        self.counters['phone_usage'] += 1
                    else:
                        self.counters['phone_usage'] = 0
            
            # 휴대폰이 감지되지 않으면 카운터 초기화
            if not phone_detected_in_frame:
                self.counters['phone_usage'] = 0
            
            if self.counters['phone_usage'] >= self.config.detection_thresholds.phone_consec_frames:
                phone_usage_detected = True
                if current_time - self.last_times['phone'] > self.warning_cooldown:
                    cv2.putText(frame, "PHONE USAGE DETECTED!", (50, 200), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 165, 255), 2)
                    terminal_message = "PHONE USAGE DETECTED"
                    self.last_times['phone'] = current_time
            
            return phone_usage_detected, terminal_message
            
        except Exception as e:
            logging.error(f"휴대폰 사용 감지 실패: {e}")
            return False, ""
    
    def reset_counters(self):
        """카운터 초기화"""
        for key in self.counters:
            self.counters[key] = 0

class ApprovalManager:
    """승인 시스템 관리 클래스"""
    
    def __init__(self, config: ConfigManager):
        self.config = config
        self.mqtt_client = None
        self.pending_approvals = {}  # sessionId -> approval_info
        self.approval_lock = threading.Lock()
        
        if MQTT_AVAILABLE and self.config.approval_config.enable_approval_system:
            self.initialize_mqtt()
    
    def initialize_mqtt(self):
        """MQTT 클라이언트 초기화"""
        try:
            # callback_api_version 명시적 설정
            self.mqtt_client = mqtt.Client(
                client_id=self.config.approval_config.mqtt_client_id,
                callback_api_version=mqtt.CallbackAPIVersion.VERSION1
            )
            self.mqtt_client.username_pw_set(
                self.config.approval_config.mqtt_username,
                self.config.approval_config.mqtt_password
            )
            
            # 콜백 설정
            self.mqtt_client.on_connect = self.on_mqtt_connect
            self.mqtt_client.on_message = self.on_mqtt_message
            
            # 연결
            self.mqtt_client.connect(
                self.config.approval_config.mqtt_broker,
                self.config.approval_config.mqtt_port
            )
            
            # 백그라운드 스레드에서 루프 실행
            self.mqtt_client.loop_start()
            
            logging.info("MQTT 클라이언트 초기화 완료")
            
        except Exception as e:
            logging.error(f"MQTT 클라이언트 초기화 실패: {e}")
            # MQTT 클라이언트 초기화 실패 시 None으로 설정
            self.mqtt_client = None
    
    def on_mqtt_connect(self, client, userdata, flags, rc):
        """MQTT 연결 콜백"""
        if rc == 0:
            logging.info("MQTT 브로커에 연결됨")
            # 응답 토픽 구독
            response_topic = f"car/{self.config.approval_config.vin}/auth/approval/response"
            client.subscribe(response_topic)
            logging.info(f"응답 토픽 구독: {response_topic}")
        else:
            logging.error(f"MQTT 연결 실패: {rc}")
    
    def on_mqtt_message(self, client, userdata, msg):
        """MQTT 메시지 수신 콜백"""
        try:
            payload = json.loads(msg.payload.decode())
            session_id = payload.get('sessionId')
            decision = payload.get('decision')
            
            logging.info(f"승인 응답 수신: sessionId={session_id}, decision={decision}")
            
            with self.approval_lock:
                if session_id in self.pending_approvals:
                    approval_info = self.pending_approvals[session_id]
                    approval_info['decision'] = decision
                    approval_info['received_time'] = time.time()
                    logging.info(f"승인 처리 완료: {decision}")
                else:
                    logging.warning(f"알 수 없는 sessionId: {session_id}")
                    
        except Exception as e:
            logging.error(f"MQTT 메시지 처리 실패: {e}")
    
    def request_approval(self, frame: np.ndarray) -> str:
        """승인 요청"""
        try:
            # 세션 ID 생성
            session_id = str(uuid.uuid4())
            
            # 테스트용 간단한 메시지 (이미지 없이)
            request_data = {
                'sessionId': session_id,
                'message': 'test_approval_request',
                'vin': self.config.approval_config.vin,
                'timestamp': int(time.time())
            }
            
            # MQTT로 요청 발송 (외부 명령어 사용)
            request_topic = f"car/{self.config.approval_config.vin}/auth/approval/request"
            message = json.dumps(request_data)
            
            # mosquitto_pub 사용
            try:
                cmd = [
                    'mosquitto_pub',
                    '-h', self.config.approval_config.mqtt_broker,
                    '-p', str(self.config.approval_config.mqtt_port),
                    '-u', self.config.approval_config.mqtt_username,
                    '-P', self.config.approval_config.mqtt_password,
                    '-t', request_topic,
                    '-m', message
                ]
                
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
                if result.returncode == 0:
                    logging.info(f"승인 요청 발송 성공: sessionId={session_id}")
                    print(f"[INFO] MQTT 승인 요청 전송: {session_id}")
                    
                    # 대기 목록에 추가
                    with self.approval_lock:
                        self.pending_approvals[session_id] = {
                            'request_time': time.time(),
                            'decision': None,
                            'received_time': None
                        }
                    
                    # 즉시 PENDING 반환 (비동기 처리)
                    logging.info(f"승인 요청 전송 완료, 응답 대기 중: {session_id}")
                    return "PENDING"
                    
                else:
                    logging.error(f"MQTT 발송 실패: {result.stderr}")
                    return "DENY"
                    
            except subprocess.TimeoutExpired:
                logging.error("MQTT 발송 타임아웃")
                return "DENY"
            except FileNotFoundError:
                logging.error("mosquitto_pub 명령어를 찾을 수 없습니다")
                return "DENY"
                
        except Exception as e:
            logging.error(f"승인 요청 실패: {e}")
            return "DENY"
    
    def cleanup(self):
        """정리"""
        if self.mqtt_client:
            self.mqtt_client.loop_stop()
            self.mqtt_client.disconnect()

class DisplayManager:
    """화면 표시 관리 클래스"""
    
    def __init__(self, config: ConfigManager):
        self.config = config
        
    def draw_face_landmarks(self, frame: np.ndarray, face_landmarks):
        """얼굴 랜드마크 그리기"""
        try:
            mp_drawing = mp.solutions.drawing_utils
            mp_drawing_styles = mp.solutions.drawing_styles
            
            # 얼굴 테셀레이션 그리기
            mp_drawing.draw_landmarks(
                image=frame,
                landmark_list=face_landmarks,
                connections=mp.solutions.face_mesh.FACEMESH_TESSELATION,
                landmark_drawing_spec=None,
                connection_drawing_spec=mp_drawing_styles.get_default_face_mesh_tesselation_style()
            )
            
            # 얼굴 윤곽선 그리기
            mp_drawing.draw_landmarks(
                image=frame,
                landmark_list=face_landmarks,
                connections=mp.solutions.face_mesh.FACEMESH_CONTOURS,
                landmark_drawing_spec=None,
                connection_drawing_spec=mp_drawing_styles.get_default_face_mesh_contours_style()
            )
            
        except Exception as e:
            logging.error(f"얼굴 랜드마크 그리기 실패: {e}")
    
    def display_info_on_frame(self, frame: np.ndarray, screen_width: int, 
                             avg_ear: float, pitch: float, yaw: float, roll: float,
                             current_status: str, performance_info: Dict[str, float],
                             current_driver: str = None, driver_baselines: Dict = None,
                             input_active: bool = False, input_buffer: str = "",
                             registration_mode: bool = False, baseline_mode: bool = False,
                             performance_mode: bool = False, clear_mode: bool = False):
        """프레임에 정보 표시"""
        try:
            # 배경 박스 (반투명)
            overlay = frame.copy()
            cv2.rectangle(overlay, (screen_width - 320, 10), (screen_width - 10, 220), (0, 0, 0), -1)
            cv2.addWeighted(overlay, 0.7, frame, 0.3, 0, frame)
            cv2.rectangle(frame, (screen_width - 320, 10), (screen_width - 10, 220), (255, 255, 255), 2)
            
            # 현재 상태 표시
            status_color = {
                "NORMAL": (0, 255, 0),    # 초록
                "WARNING": (0, 255, 255), # 노랑
                "CAUTION": (0, 165, 255), # 주황
                "DANGER": (0, 0, 255),    # 빨강
                "CRITICAL": (255, 0, 255), # 마젠타
                "UNKNOWN": (128, 128, 128) # 회색
            }
            
            color = status_color.get(current_status, (255, 255, 255))
            cv2.putText(frame, f"STATUS: {current_status}", (screen_width - 310, 35), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.8, color, 2)
            
            # EAR 정보
            ear_color = (0, 255, 0) if avg_ear >= self.config.detection_thresholds.eye_ar_thresh else (0, 0, 255)
            cv2.putText(frame, f"EAR: {avg_ear:.3f}", (screen_width - 310, 65), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, ear_color, 2)
            
            # 고개 자세 정보
            # pitch_color: baseline 존재 시 상대 비교
            if current_driver and driver_baselines and current_driver in driver_baselines:
                bl = driver_baselines[current_driver]
                if bl and bl.get("BASELINE_PITCH") is not None:
                    pitch_color = (0, 255, 0) if (pitch - bl["BASELINE_PITCH"]) > -5 else (0, 0, 255)
                else:
                    pitch_color = (0, 255, 0) if pitch >= self.config.detection_thresholds.pitch_down_thresh else (0, 0, 255)
            else:
                pitch_color = (0, 255, 0) if pitch >= self.config.detection_thresholds.pitch_down_thresh else (0, 0, 255)
            
            # yaw_color, roll_color: baseline 존재 시 상대 비교
            if current_driver and driver_baselines and current_driver in driver_baselines:
                bl = driver_baselines[current_driver]
                if bl and bl.get("BASELINE_YAW") is not None:
                    yaw_delta = abs(yaw - bl["BASELINE_YAW"])
                    yaw_color = (0, 255, 0) if yaw_delta <= 15.0 else (0, 255, 255)
                else:
                    yaw_color = (0, 255, 0) if abs(yaw) <= self.config.detection_thresholds.yaw_thresh else (0, 255, 255)
                
                if bl and bl.get("BASELINE_ROLL") is not None:
                    roll_delta = abs(roll - bl["BASELINE_ROLL"])
                    roll_color = (0, 255, 0) if roll_delta <= 12.0 else (0, 255, 255)
                else:
                    roll_color = (0, 255, 0) if abs(roll) <= self.config.detection_thresholds.roll_thresh else (0, 255, 255)
            else:
                yaw_color = (0, 255, 0) if abs(yaw) <= self.config.detection_thresholds.yaw_thresh else (0, 255, 255)
                roll_color = (0, 255, 0) if abs(roll) <= self.config.detection_thresholds.roll_thresh else (0, 255, 255)
            
            cv2.putText(frame, f"Pitch: {pitch:.1f}", (screen_width - 310, 95), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, pitch_color, 2)
            cv2.putText(frame, f"Yaw: {yaw:.1f}", (screen_width - 310, 125), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, yaw_color, 2)
            cv2.putText(frame, f"Roll: {roll:.1f}", (screen_width - 310, 155), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, roll_color, 2)
            
            # 성능 정보
            cv2.putText(frame, f"FPS: {performance_info['fps']:.1f}", (screen_width - 310, 185), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 1)
            
            # 입력 상태 표시
            if input_active:
                # 입력 배경 박스
                cv2.rectangle(frame, (50, 50), (600, 120), (0, 0, 0), -1)
                cv2.rectangle(frame, (50, 50), (600, 120), (255, 255, 255), 2)
                
                # 입력 프롬프트
                if registration_mode:
                    prompt = "사용자 이름을 입력하세요:"
                elif baseline_mode:
                    prompt = "베이스라인 측정 옵션 (1-4):"
                elif performance_mode:
                    prompt = "성능 설정 옵션 (1-6):"
                elif clear_mode:
                    prompt = "정말로 모든 데이터를 삭제하시겠습니까? (y/N):"
                else:
                    prompt = "입력:"
                
                cv2.putText(frame, prompt, (70, 80),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
                
                # 입력 버퍼
                cv2.putText(frame, f"{input_buffer}_", (70, 110),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 255), 2)
            
        except Exception as e:
            logging.error(f"정보 표시 실패: {e}")
    
    def display_baseline_progress(self, frame: np.ndarray, progress: int, remaining_time: int, 
                                 collected_frames: int, user_name: str):
        """베이스라인 측정 진행률 표시"""
        try:
            # 배경 박스 (반투명)
            overlay = frame.copy()
            cv2.rectangle(overlay, (50, 50), (600, 200), (0, 0, 0), -1)
            cv2.addWeighted(overlay, 0.7, frame, 0.3, 0, frame)
            cv2.rectangle(frame, (50, 50), (600, 200), (255, 255, 255), 2)
            
            # 제목
            cv2.putText(frame, f"Baseline Measurement - {user_name}", (70, 80),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
            
            # 진행률 퍼센트
            cv2.putText(frame, f"Progress: {progress}%", (70, 110),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 255), 3)
            
            # 남은 시간
            cv2.putText(frame, f"Time left: {remaining_time}s", (70, 135),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)
            
            # 수집된 프레임 수
            cv2.putText(frame, f"Collected frames: {collected_frames}", (70, 160),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)
            
            # 진행률 바
            bar_width = 500
            bar_height = 25
            bar_x, bar_y = 70, 180
            
            # 배경 바
            cv2.rectangle(frame, (bar_x, bar_y), (bar_x + bar_width, bar_y + bar_height), (100, 100, 100), -1)
            cv2.rectangle(frame, (bar_x, bar_y), (bar_x + bar_width, bar_y + bar_height), (255, 255, 255), 2)
            
            # 진행 바
            progress_width = int((progress / 100) * bar_width)
            if progress_width > 0:
                color = (0, 255, 0) if progress < 50 else (0, 255, 255) if progress < 80 else (0, 0, 255)
                cv2.rectangle(frame, (bar_x, bar_y), (bar_x + progress_width, bar_y + bar_height), color, -1)
            
            # 진행률 퍼센트를 바 위에 표시
            cv2.putText(frame, f"{progress}%", (bar_x + bar_width + 10, bar_y + 20),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
            
            # 안내 메시지
            cv2.putText(frame, "Please look at camera normally (eyes open, head straight)", (50, 350),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
            cv2.putText(frame, "Press ESC to cancel", (50, 380),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (200, 200, 200), 1)
            
        except Exception as e:
            logging.error(f"베이스라인 진행률 표시 실패: {e}")
    
    def display_auto_registration_progress(self, frame: np.ndarray, progress: int, remaining_time: int, 
                                          registered_angles: int, user_name: str):
        """자동 얼굴 등록 진행률 표시"""
        try:
            # 배경 박스 (반투명)
            overlay = frame.copy()
            cv2.rectangle(overlay, (50, 50), (600, 200), (0, 0, 0), -1)
            cv2.addWeighted(overlay, 0.7, frame, 0.3, 0, frame)
            cv2.rectangle(frame, (50, 50), (600, 200), (255, 255, 255), 2)
            
            # 제목
            cv2.putText(frame, f"Auto Face Registration - {user_name}", (70, 80),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
            
            # 진행률 퍼센트
            cv2.putText(frame, f"Progress: {progress}%", (70, 110),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 255), 3)
            
            # 남은 시간
            cv2.putText(frame, f"Time left: {remaining_time}s", (70, 135),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)
            
            # 등록된 각도 수
            cv2.putText(frame, f"Registered angles: {registered_angles}/3", (70, 160),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)
            
            # 진행률 바
            bar_width = 500
            bar_height = 25
            bar_x, bar_y = 70, 180
            
            # 배경 바
            cv2.rectangle(frame, (bar_x, bar_y), (bar_x + bar_width, bar_y + bar_height), (100, 100, 100), -1)
            cv2.rectangle(frame, (bar_x, bar_y), (bar_x + bar_width, bar_y + bar_height), (255, 255, 255), 2)
            
            # 진행 바
            progress_width = int((progress / 100) * bar_width)
            if progress_width > 0:
                color = (0, 255, 0) if progress < 50 else (0, 255, 255) if progress < 80 else (0, 0, 255)
                cv2.rectangle(frame, (bar_x, bar_y), (bar_x + progress_width, bar_y + bar_height), color, -1)
            
            # 진행률 퍼센트를 바 위에 표시
            cv2.putText(frame, f"{progress}%", (bar_x + bar_width + 10, bar_y + 20),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
            
            # 안내 메시지
            cv2.putText(frame, "Please look at camera from different angles", (50, 350),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
            cv2.putText(frame, "Press ESC to cancel", (50, 380),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (200, 200, 200), 1)
            
        except Exception as e:
            logging.error(f"자동 등록 진행률 표시 실패: {e}")

class DriverMonitor:
    """메인 운전자 모니터링 클래스"""
    
    def __init__(self, config_file: str = "config.json"):
        # 설정 관리
        self.config = ConfigManager(config_file)
        
        # 성능 모니터링
        self.performance_monitor = PerformanceMonitor()
        
        # 얼굴 처리
        self.face_processor = FaceProcessor(self.config)
        
        # YOLO 객체 감지
        self.yolo_detector = YOLODetector(self.config)
        
        # 감지 관리
        self.detection_manager = DetectionManager(self.config)
        
        # 화면 표시 관리
        self.display_manager = DisplayManager(self.config)
        
        # 승인 시스템 관리
        self.approval_manager = ApprovalManager(self.config)
        
        # 상태 변수
        self.current_driver = None
        self.driver_thresholds = {}
        self.driver_baselines = {}
        self.current_status = "NORMAL"
        self.identification_status = "Not Identified"
        
        # 베이스라인 측정 관련
        self.baseline_measurement_active = False
        self.baseline_start_time = None
        self.baseline_duration = 300
        self.baseline_data = []
        
        # 자동 얼굴 등록 관련
        self.auto_face_registration_active = False
        self.registration_start_time = None
        self.registration_duration = 60
        self.registration_data = []
        self.registration_user_name = "DriverA"
        
        # 새 사용자 등록 관련
        self.new_user_registration_active = False
        self.new_user_registration_start_time = None
        self.new_user_registration_duration = 600
        self.new_user_registration_data = []
        
        # 카메라 관련
        self.cap = None
        self.frame_counter = 0
        
        # 자동 알림 관련
        self.last_alert_time = 0
        self.alert_cooldown = 5
        
        # 디바운스 관련 (시간 기반 상태 전환)
        self.last_status_change_time = 0
        self.last_status = "NORMAL"
        
        # 비동기 입력 처리 관련
        self.registration_mode = False
        self.baseline_mode = False
        self.performance_mode = False
        self.clear_mode = False
        self.registration_prompt = ""
        self.baseline_prompt = ""
        self.performance_prompt = ""
        self.clear_prompt = ""
        self.input_buffer = ""
        self.input_active = False
        
        logging.info("DriverMonitor 초기화 완료")
    
    def initialize_jetson_optimization(self):
        """Jetson 최적화 초기화"""
        try:
            # CUDA 사용 가능 여부 확인
            try:
                import torch
                cuda_available = torch.cuda.is_available()
                logging.info(f"CUDA 사용 가능: {cuda_available}")
                if cuda_available:
                    logging.info(f"GPU 메모리: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f}GB")
            except ImportError:
                logging.warning("PyTorch가 설치되지 않음")
                cuda_available = False
            
            # Jetson 전력 모드 설정
            if self.config.jetson_config.enable_jetson_clocks:
                try:
                    # 전력 모드 설정 (sudo 권한 필요)
                    power_mode = self.config.jetson_config.power_mode
                    logging.info(f"Jetson 전력 모드 설정: {power_mode}")
                    # 실제로는 sudo 명령어 실행이 필요하지만, 여기서는 로그만 출력
                    logging.info("실행 명령어: sudo nvpmodel -m 2 && sudo jetson_clocks")
                except Exception as e:
                    logging.warning(f"Jetson 전력 모드 설정 실패: {e}")
            
            # GPU 가속 설정
            if self.config.jetson_config.enable_gpu_acceleration and cuda_available:
                self.config.performance_config.enable_gpu = True
                logging.info("GPU 가속 활성화")
            else:
                self.config.performance_config.enable_gpu = False
                logging.info("CPU 모드로 실행")
            
            logging.info("Jetson 최적화 초기화 완료")
            
        except Exception as e:
            logging.error(f"Jetson 최적화 초기화 실패: {e}")
    
    def initialize_camera(self) -> bool:
        """카메라 초기화 (Jetson 최적화)"""
        try:
            # Jetson CSI 카메라 지원
            camera_type = self.config.jetson_config.camera_type
            
            if camera_type == 'csi':
                # CSI 카메라용 GStreamer 파이프라인
                gst_str = (
                    "nvarguscamerasrc ! "
                    "video/x-raw(memory:NVMM), width=640, height=480, format=NV12, framerate=30/1 ! "
                    "nvvidconv ! video/x-raw, format=BGRx ! "
                    "videoconvert ! video/x-raw, format=BGR ! "
                    "appsink"
                )
                self.cap = cv2.VideoCapture(gst_str, cv2.CAP_GSTREAMER)
                logging.info("CSI 카메라 초기화 시도")
            else:
                # USB 카메라 (기본)
                self.cap = cv2.VideoCapture(0)
                logging.info("USB 카메라 초기화 시도")
            
            if not self.cap.isOpened():
                logging.error("카메라를 열 수 없습니다")
                return False
            
            # 성능 최적화: 웹캠 해상도 설정
            if self.config.performance_config.performance_mode:
                self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, self.config.performance_config.webcam_resolution[0])
                self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, self.config.performance_config.webcam_resolution[1])
                logging.info(f"성능 모드: 해상도 {self.config.performance_config.webcam_resolution[0]}x{self.config.performance_config.webcam_resolution[1]}")
            
            # Jetson 성능 최적화 설정
            cv2.setNumThreads(1)  # OpenCV 스레드 수 제한
            
            logging.info("카메라 초기화 완료")
            return True
            
        except Exception as e:
            logging.error(f"카메라 초기화 실패: {e}")
            return False
    
    def load_driver_data(self):
        """운전자 데이터 로드"""
        try:
            # 개인별 임계치 로드
            thresholds_file = os.path.join(self.config.path_config.data_dir, "driver_thresholds.json")
            if os.path.exists(thresholds_file):
                with open(thresholds_file, 'r') as f:
                    self.driver_thresholds = json.load(f)
                logging.info(f"운전자 임계치 로드 완료: {len(self.driver_thresholds)}명")
            
            # 개인별 베이스라인 로드
            baseline_file = os.path.join(self.config.path_config.data_dir, "baseline.json")
            if os.path.exists(baseline_file):
                with open(baseline_file, 'r') as f:
                    self.driver_baselines = json.load(f)
                logging.info(f"운전자 베이스라인 로드 완료: {len(self.driver_baselines)}명")
                
        except Exception as e:
            logging.error(f"운전자 데이터 로드 실패: {e}")
    
    def save_driver_data(self):
        """운전자 데이터 자동 저장"""
        try:
            # 데이터 디렉토리 생성
            os.makedirs(self.config.path_config.data_dir, exist_ok=True)
            
            # 개인별 임계치 저장
            thresholds_file = os.path.join(self.config.path_config.data_dir, "driver_thresholds.json")
            with open(thresholds_file, 'w') as f:
                json.dump(self.driver_thresholds, f, indent=2)
            
            # 개인별 베이스라인 저장
            baseline_file = os.path.join(self.config.path_config.data_dir, "baseline.json")
            with open(baseline_file, 'w') as f:
                json.dump(self.driver_baselines, f, indent=2)
                
            logging.info("운전자 데이터 자동 저장 완료")
            
        except Exception as e:
            logging.error(f"운전자 데이터 저장 실패: {e}")
    
    def auto_recognize_driver(self, frame: np.ndarray) -> Tuple[bool, str]:
        """자동 운전자 인식 (승인 시스템 포함)"""
        try:
            identified_name = self.face_processor.identify_driver(frame)
            
            # 얼굴이 없거나 오류인 경우
            if identified_name in ["No Face", "Multiple Faces", "Encoding Failed", "Identification Error"]:
                return False, identified_name
            
            # 등록된 사용자가 없는 경우
            # 등록된 사용자가 없는 경우 - 첫 사용자를 Owner로 자동 등록
            if identified_name == "No Registered":
                logging.info("등록된 사용자가 없음 - 첫 사용자를 Owner로 자동 등록")
                if self.face_processor.register_driver_face(frame, "Owner"):
                    logging.info("첫 사용자 등록 완료: Owner")
                    self.current_driver = "Owner"
                    return True, "Owner"
                else:
                    logging.error("첫 사용자 등록 실패")
                    return False, "Registration Failed"
            
            # 미등록 사용자 또는 불확실한 매치인 경우 승인 요청
            if identified_name in ["Unknown Driver", "Uncertain"]:
                logging.warning(f"{identified_name} 감지 - 승인 요청 시작")
                
                # 승인 요청
                decision = self.approval_manager.request_approval(frame)
                
                if decision == "APPROVE":
                    # 승인됨 - 새 사용자로 등록
                    new_user_name = f"ApprovedUser_{int(time.time())}"
                    if self.face_processor.register_driver_face(frame, new_user_name):
                        logging.info(f"새 사용자 등록 완료: {new_user_name}")
                        self.current_driver = new_user_name
                        return True, new_user_name
                    else:
                        logging.error("새 사용자 등록 실패")
                        return False, "Registration Failed"
                else:
                    # 거부됨
                    logging.warning("사용자 승인 거부됨")
                    return False, "Approval Denied"
            
            # 새로운 운전자가 인식된 경우
            if self.current_driver != identified_name:
                logging.info(f"새로운 운전자 감지: {identified_name}")
                self.current_driver = identified_name
                
                # 개인별 임계치 적용
                if identified_name in self.driver_thresholds:
                    self.apply_personal_thresholds(identified_name)
                    logging.info(f"개인별 임계치 적용 완료: {identified_name}")
                    print(f"[INFO] 개인별 임계치 적용: {identified_name}")
                else:
                    logging.info(f"개인별 임계치 없음: {identified_name}")
                    print(f"[INFO] 기본 임계치 사용: {identified_name}")
                
                            # 개인별 베이스라인 로드
            if identified_name in self.driver_baselines:
                logging.info(f"개인별 베이스라인 로드 완료: {identified_name}")
            else:
                logging.info(f"개인별 베이스라인 없음: {identified_name}")
                # 베이스라인이 없으면 자동 측정 시작 (DriverA 제외)
                if not self.baseline_measurement_active and identified_name != "DriverA":
                    print(f"[INFO] No baseline for {identified_name}. Starting auto baseline measurement...")
                    self.start_baseline_measurement(identified_name, self.config.auto_setup_config.baseline_duration)
                
                # 자동 저장
                self.save_driver_data()
                
                return True, identified_name
            
            return True, identified_name
            
        except Exception as e:
            logging.error(f"자동 운전자 인식 실패: {e}")
            return False, "Recognition Error"
    
    def apply_personal_thresholds(self, driver_name: str):
        """개인별 임계치 적용"""
        try:
            if driver_name in self.driver_thresholds:
                thresholds = self.driver_thresholds[driver_name]
                self.config.detection_thresholds.eye_ar_thresh = thresholds.get('EYE_AR_THRESH', self.config.detection_thresholds.eye_ar_thresh)
                self.config.detection_thresholds.pitch_down_thresh = thresholds.get('PITCH_DOWN_THRESH', self.config.detection_thresholds.pitch_down_thresh)
                self.config.detection_thresholds.yaw_thresh = thresholds.get('YAW_THRESH', self.config.detection_thresholds.yaw_thresh)
                self.config.detection_thresholds.roll_thresh = thresholds.get('ROLL_THRESH', self.config.detection_thresholds.roll_thresh)
                logging.info(f"개인별 임계치 적용: {driver_name}")
            
            # 7. Baseline Auto-Correction Range 제한 - 베이스라인이 있으면 eye_ar_thresh 자동 조정
            if driver_name in self.driver_baselines:
                bl = self.driver_baselines[driver_name]
                if bl.get("BASELINE_EYE_AR"):
                    # 상하한 범위 제한 (0.15 ~ 0.32)
                    self.config.detection_thresholds.eye_ar_thresh = min(max(0.15, bl["BASELINE_EYE_AR"] * 0.80), 0.32)
                    logging.info(f"베이스라인 기반 eye_ar_thresh 조정: {self.config.detection_thresholds.eye_ar_thresh:.3f}")
                    
        except Exception as e:
            logging.error(f"개인별 임계치 적용 실패: {e}")
    
    def start_baseline_measurement(self, user_name: str, duration: int = None):
        """베이스라인 측정 시작"""
        if duration is None:
            duration = self.config.baseline_config.duration_default
        
        self.baseline_measurement_active = True
        self.baseline_start_time = time.time()
        self.baseline_duration = duration
        self.baseline_data = []
        
        logging.info(f"베이스라인 측정 시작: {user_name} ({duration}초)")
    
    def start_auto_face_registration(self, user_name: str = None, duration: int = None):
        """자동 얼굴 등록 시작"""
        if user_name is None:
            user_name = self.config.auto_setup_config.default_user_name
        if duration is None:
            duration = self.config.auto_setup_config.registration_duration
        
        self.auto_face_registration_active = True
        self.registration_start_time = time.time()
        self.registration_duration = duration
        self.registration_data = []
        self.registration_user_name = user_name
        
        logging.info(f"자동 얼굴 등록 시작: {user_name} ({duration}초)")
    
    def process_auto_face_registration(self, frame: np.ndarray) -> Tuple[bool, str]:
        """자동 얼굴 등록 처리"""
        if not self.auto_face_registration_active:
            return False, ""
        
        current_time = time.time()
        elapsed_time = current_time - self.registration_start_time
        remaining_time = self.registration_duration - elapsed_time
        
        if remaining_time <= 0:
            # 등록 완료
            self.auto_face_registration_active = False
            self.save_auto_registration_data()
            logging.info(f"자동 얼굴 등록 완료: {self.registration_user_name}")
            return True, "Auto Registration Complete"
        
        # 진행률 계산
        progress = int((elapsed_time / self.registration_duration) * 100)
        
        # 얼굴 등록 시도 (1초마다)
        if int(elapsed_time) % 2 == 0 and len(self.registration_data) < 3:
            if self.face_processor.register_driver_face(frame, self.registration_user_name):
                self.registration_data.append(current_time)
        
        # 진행률 표시
        self.display_manager.display_auto_registration_progress(
            frame, progress, int(remaining_time), len(self.registration_data), self.registration_user_name
        )
        
        return False, f"Auto Registration in progress: {progress}%"
    
    def save_auto_registration_data(self):
        """자동 등록 데이터 저장"""
        try:
            if len(self.registration_data) > 0:
                logging.info(f"자동 얼굴 등록 완료: {self.registration_user_name} ({len(self.registration_data)}개 각도)")
            else:
                logging.warning("자동 얼굴 등록 실패: 얼굴이 감지되지 않음")
                
        except Exception as e:
            logging.error(f"자동 등록 데이터 저장 실패: {e}")
    
    def process_baseline_measurement(self, frame: np.ndarray, user_name: str) -> Tuple[bool, str]:
        """베이스라인 측정 처리"""
        if not self.baseline_measurement_active:
            return False, ""
        
        current_time = time.time()
        elapsed_time = current_time - self.baseline_start_time
        remaining_time = self.baseline_duration - elapsed_time
        
        if remaining_time <= 0:
            # 측정 완료
            self.baseline_measurement_active = False
            self.save_baseline_data(user_name)
            logging.info(f"베이스라인 측정 완료: {user_name}")
            return True, "Baseline Complete"
        
        # 진행률 계산
        progress = int((elapsed_time / self.baseline_duration) * 100)
        
        # 데이터 수집
        face_result = self.face_processor.process_face(frame)
        if face_result['success']:
            self.baseline_data.append({
                'ear': face_result['ear'],
                'pitch': face_result['pitch'] if face_result['pitch'] is not None else 0,  # 부호 유지
                'yaw': face_result['yaw'] if face_result['yaw'] is not None else 0,      # 부호 유지
                'roll': face_result['roll'] if face_result['roll'] is not None else 0    # 부호 유지
            })
        
        # 진행률 표시
        self.display_manager.display_baseline_progress(
            frame, progress, int(remaining_time), len(self.baseline_data), user_name
        )
        
        return False, f"Baseline in progress: {progress}%"
    
    def save_baseline_data(self, user_name: str):
        """베이스라인 데이터 저장"""
        try:
            if not self.baseline_data:
                logging.warning("저장할 베이스라인 데이터가 없습니다")
                return
            
            # 평균값 계산 (부호 유지)
            avg_ear = sum(d['ear'] for d in self.baseline_data) / len(self.baseline_data)
            avg_pitch = sum(d['pitch'] for d in self.baseline_data) / len(self.baseline_data)  # 부호 유지
            avg_yaw = sum(d['yaw'] for d in self.baseline_data) / len(self.baseline_data)      # 부호 유지
            avg_roll = sum(d['roll'] for d in self.baseline_data) / len(self.baseline_data)    # 부호 유지
            
            baseline = {
                "BASELINE_EYE_AR": avg_ear,
                "BASELINE_PITCH": avg_pitch,
                "BASELINE_YAW": avg_yaw,
                "BASELINE_ROLL": avg_roll
            }
            
            # 파일에 저장
            baseline_file = os.path.join(self.config.path_config.data_dir, "baseline.json")
            baseline_data = {}
            if os.path.exists(baseline_file):
                with open(baseline_file, 'r') as f:
                    baseline_data = json.load(f)
            
            baseline_data[user_name] = baseline
            
            with open(baseline_file, 'w') as f:
                json.dump(baseline_data, f, indent=4)
            
            self.driver_baselines[user_name] = baseline
            logging.info(f"베이스라인 데이터 저장 완료: {user_name}")
            
            # 베이스라인 기반으로 개인별 임계치 자동 생성
            self.generate_personal_thresholds(user_name, baseline)
            
        except Exception as e:
            logging.error(f"베이스라인 데이터 저장 실패: {e}")
    
    def generate_personal_thresholds(self, user_name: str, baseline: dict):
        """베이스라인 기반으로 개인별 임계치 자동 생성"""
        try:
            # 기본 임계치 가져오기
            default_thresholds = self.config.detection_thresholds
            
            # 베이스라인 기반 개인별 임계치 계산
            personal_thresholds = {
                'EYE_AR_THRESH': max(0.15, min(0.32, baseline.get('BASELINE_EYE_AR', default_thresholds.eye_ar_thresh) * 0.85)),
                'PITCH_DOWN_THRESH': baseline.get('BASELINE_PITCH', default_thresholds.pitch_down_thresh) - 5.0,
                'YAW_THRESH': max(15.0, min(45.0, abs(baseline.get('BASELINE_YAW', default_thresholds.yaw_thresh)) + 10.0)),
                'ROLL_THRESH': max(8.0, min(20.0, abs(baseline.get('BASELINE_ROLL', default_thresholds.roll_thresh)) + 5.0))
            }
            
            # 개인별 임계치 저장
            self.driver_thresholds[user_name] = personal_thresholds
            
            # 파일에 저장
            thresholds_file = os.path.join(self.config.path_config.data_dir, "driver_thresholds.json")
            with open(thresholds_file, 'w') as f:
                json.dump(self.driver_thresholds, f, indent=4)
            
            logging.info(f"개인별 임계치 자동 생성 완료: {user_name}")
            print(f"[INFO] 개인별 임계치 자동 생성: {user_name}")
            print(f"[INFO] EAR: {personal_thresholds['EYE_AR_THRESH']:.3f}, Yaw: {personal_thresholds['YAW_THRESH']:.1f}, Roll: {personal_thresholds['ROLL_THRESH']:.1f}")
            
        except Exception as e:
            logging.error(f"개인별 임계치 생성 실패: {e}")
    
    def auto_alert_system(self, current_time: float):
        """자동 알림 시스템"""
        if current_time - self.last_alert_time < self.alert_cooldown:
            return
        
        # 상태별 자동 알림
        if self.current_status == "DANGER":
            logging.warning("🚨 [AUTO ALERT] DANGER DETECTED! - Drowsiness detected! Stop driving immediately!")
            self.last_alert_time = current_time
        elif self.current_status == "CAUTION":
            logging.warning("⚠️ [AUTO ALERT] CAUTION - Distraction detected! Look forward!")
            self.last_alert_time = current_time
        elif self.current_status == "WARNING":
            logging.info("⚠️ [AUTO ALERT] WARNING - Attention needed.")
            self.last_alert_time = current_time
    
    def process_frame(self, frame: np.ndarray) -> Dict[str, any]:
        """프레임 처리"""
        frame_start_time = time.time()
        
        try:
            # 성능 최적화: 프레임 스킵
            self.frame_counter += 1
            if (self.config.performance_config.performance_mode and 
                self.frame_counter % self.config.performance_config.skip_frames != 0):
                return {'success': False, 'message': 'Frame skipped'}
            
            # 프레임 좌우 반전
            frame = cv2.flip(frame, 1)
            
            # 얼굴 처리
            face_result = self.face_processor.process_face(frame)
            
            # 성능 최적화: YOLO 감지 간격 조절
            detected_objects = []
            if self.frame_counter % self.config.performance_config.yolo_detection_interval == 0:
                detected_objects = self.yolo_detector.detect_objects(frame, self.frame_counter)
            
            # 성능 최적화: 얼굴 인식 간격 조절 (항상 실행)
            if self.frame_counter % self.config.performance_config.face_recognition_interval == 0:
                auto_success, auto_result = self.auto_recognize_driver(frame)
                if auto_success and auto_result not in ["No Face", "Multiple Faces", "Encoding Failed", "No Registered", "Unknown Driver", "Identification Error"]:
                    self.identification_status = f"Auto: {auto_result}"
                    
                    # 베이스라인 측정 중에 다른 운전자가 오면 중단하고 새 운전자 측정 시작
                    if self.baseline_measurement_active and self.current_driver != auto_result:
                        print(f"[WARNING] Different driver detected during baseline measurement: {auto_result}")
                        print(f"[WARNING] Stopping baseline measurement for {self.current_driver}")
                        self.baseline_measurement_active = False
                        
                        # 새로운 운전자에 대해 베이스라인 측정 시작
                        if auto_result not in self.driver_baselines:
                            print(f"[INFO] Starting baseline measurement for new driver: {auto_result}")
                            self.start_baseline_measurement(auto_result, self.config.auto_setup_config.baseline_duration)
                        
                        self.identification_status = f"Baseline interrupted by {auto_result}"
                    
                    # 자동 베이스라인 측정 대기 중이면 시작
                    if hasattr(self, 'auto_baseline_waiting') and self.auto_baseline_waiting:
                        print(f"[INFO] First driver detected: {auto_result}. Starting auto baseline measurement...")
                        self.start_baseline_measurement(auto_result, self.config.auto_setup_config.baseline_duration)
                        self.auto_baseline_waiting = False
                        
                elif auto_result == "Unknown Driver":
                    self.identification_status = "Unknown Driver - Press 'N' to register"
            
            # 자동 얼굴 등록 처리
            if self.auto_face_registration_active:
                registration_success, registration_result = self.process_auto_face_registration(frame)
                if registration_success:
                    self.auto_face_registration_active = False
                    self.identification_status = f"Auto Registration Complete: {self.registration_user_name}"
                    # 등록 완료 후 베이스라인 측정 시작
                    if not os.path.exists(self.config.path_config.baseline_path):
                        self.start_baseline_measurement(self.registration_user_name)
            
            # 베이스라인 측정 처리
            if self.baseline_measurement_active:
                baseline_success, baseline_result = self.process_baseline_measurement(frame, self.current_driver or "Unknown")
                if baseline_success:
                    self.baseline_measurement_active = False
                    self.identification_status = f"Baseline Complete: {self.current_driver}"
            
            # 감지 처리
            drowsiness_detected = False
            distraction_detected = False
            phone_usage_detected = False
            terminal_messages = []
            
            if face_result['success']:
                # 얼굴 감지 시 no_face_counter 리셋
                self.no_face_counter = 0
                
                # 얼굴 랜드마크 그리기
                self.display_manager.draw_face_landmarks(frame, face_result['landmarks'])
                
                # 헤드포즈 None/이상치 안전장치
                pitch = face_result['pitch'] if face_result['pitch'] is not None else 0.0
                yaw = face_result['yaw'] if face_result['yaw'] is not None else 0.0
                roll = face_result['roll'] if face_result['roll'] is not None else 0.0
                
                # 극단값 클램프
                pitch = float(np.clip(pitch, -89.0, 89.0))
                yaw = float(np.clip(yaw, -89.0, 89.0))
                roll = float(np.clip(roll, -89.0, 89.0))
                
                # 현재 운전자의 baseline 가져오기
                current_baseline = None
                if self.current_driver and self.current_driver in self.driver_baselines:
                    current_baseline = self.driver_baselines[self.current_driver]
                
                # 졸음 감지 (baseline 기반)
                drowsiness_detected, drowsy_msg = self.detection_manager.check_drowsiness(
                    frame, face_result['ear'], pitch, time.time(), current_baseline
                )
                if drowsy_msg:
                    terminal_messages.append(drowsy_msg)
                
                # 시선 이탈 감지 (baseline 기반)
                distraction_detected, dist_msg = self.detection_manager.check_distraction(
                    frame, yaw, roll, time.time(), current_baseline
                )
                if dist_msg:
                    terminal_messages.append(dist_msg)
                
                # 휴대폰 사용 감지
                phone_usage_detected, phone_msg = self.detection_manager.check_phone_usage(
                    frame, detected_objects, face_result['landmarks'], time.time(),
                    frame.shape[1], frame.shape[0], pitch, yaw
                )
                if phone_msg:
                    terminal_messages.append(phone_msg)
                
                # 상태 업데이트 (디바운스 적용)
                current_time = time.time()
                new_status = "NORMAL"
                
                if drowsiness_detected:
                    new_status = "DANGER"
                elif phone_usage_detected or distraction_detected:
                    new_status = "CAUTION"
                elif (self.detection_manager.counters['eyes_closed'] >= 2 or 
                      self.detection_manager.counters['head_down'] >= 2):
                    new_status = "WARNING"
                
                # 디바운스: 상태 변경 시 최소 지속 시간 확인
                if new_status != self.last_status:
                    if current_time - self.last_status_change_time >= (self.config.detection_thresholds.danger_cooldown_ms / 1000.0 if new_status == "DANGER" else self.config.detection_thresholds.warning_cooldown_ms / 1000.0):
                        self.current_status = new_status
                        self.last_status = new_status
                        self.last_status_change_time = current_time
                else:
                    self.current_status = new_status
                
                # 정보 표시 (클램프된 값 사용)
                performance_info = self.performance_monitor.get_performance_info()
                self.display_manager.display_info_on_frame(
                    frame, frame.shape[1], face_result['ear'], pitch,  # 클램프된 pitch 사용
                    yaw, roll, self.current_status, performance_info,  # 클램프된 yaw, roll 사용
                    self.current_driver, self.driver_baselines,
                    self.input_active, self.input_buffer,  # 입력 상태 전달
                    self.registration_mode, self.baseline_mode,  # 모드 상태 전달
                    self.performance_mode, self.clear_mode
                )
            else:
                # 6. FaceMesh Failure Counter Reset Scope - 얼굴 미감지 시 카운터 리셋
                self.detection_manager.reset_counters()
                
                # 얼굴 미감지 연속 프레임 카운터
                self.no_face_counter = getattr(self, 'no_face_counter', 0) + 1
                
                # N 프레임 연속 미감지 시 UNKNOWN 상태
                if self.no_face_counter >= 10:  # 10프레임 연속 미감지
                    self.current_status = "UNKNOWN"
                    cv2.putText(frame, "NO FACE DETECTED", (50, 50), cv2.FONT_HERSHEY_SIMPLEX, 1, (128, 128, 128), 2)
                else:
                    self.current_status = "NORMAL"
            
            # 성능 모니터링 업데이트
            self.performance_monitor.update_fps()
            frame_time = time.time() - frame_start_time
            self.performance_monitor.add_frame_time(frame_time)
            
            # 자동 알림 시스템
            self.auto_alert_system(time.time())
            
            return {
                'success': True,
                'face_detected': face_result['success'],
                'drowsiness_detected': drowsiness_detected,
                'distraction_detected': distraction_detected,
                'phone_usage_detected': phone_usage_detected,
                'terminal_messages': terminal_messages,
                'current_status': self.current_status
            }
            
        except Exception as e:
            logging.error(f"프레임 처리 실패: {e}")
            return {'success': False, 'error': str(e)}
    
    def cleanup(self):
        """리소스 정리"""
        try:
            if hasattr(self, 'cap') and self.cap:
                self.cap.release()
            
            if hasattr(self, 'yolo_detector') and self.yolo_detector:
                self.yolo_detector.stop()
            
            if hasattr(self, 'face_processor') and self.face_processor:
                del self.face_processor
            
            # 승인 시스템 정리
            if hasattr(self, 'approval_manager'):
                try:
                    self.approval_manager.cleanup()
                except Exception as e:
                    logging.error(f"승인 시스템 정리 실패: {e}")
            
            cv2.destroyAllWindows()
            logging.info("리소스 정리 완료")
            
        except Exception as e:
            logging.error(f"리소스 정리 실패: {e}")
    
    def handle_async_input(self, key: int) -> bool:
        """비동기 입력 처리"""
        if not self.input_active:
            return False
        
        if key == 13:  # Enter key
            if self.input_buffer.strip():
                if self.registration_mode:
                    user_name = self.input_buffer.strip()
                    print(f"[INFO] 사용자 등록 시도: {user_name}")
                    self.pending_registration = user_name
                    self.registration_mode = False
                    self.input_active = False
                    self.input_buffer = ""
                    return True
                elif self.baseline_mode:
                    choice = self.input_buffer.strip()
                    duration = self.config.baseline_config.duration_default
                    if choice == '1':
                        duration = self.config.baseline_config.duration_quick
                    elif choice == '2':
                        duration = self.config.baseline_config.duration_default
                    elif choice == '3':
                        duration = self.config.baseline_config.duration_full
                    elif choice == '4':
                        print("[INFO] 사용자 지정 시간 모드 - 기본값(5분) 사용")
                    
                    user_name = self.current_driver or "Unknown"
                    self.start_baseline_measurement(user_name, duration)
                    self.baseline_mode = False
                    self.input_active = False
                    self.input_buffer = ""
                    return True
                elif self.performance_mode:
                    choice = self.input_buffer.strip()
                    if choice == '1':
                        self.config.performance_config.performance_mode = not self.config.performance_config.performance_mode
                        print(f"[INFO] 성능 모드: {'ON' if self.config.performance_config.performance_mode else 'OFF'}")
                    elif choice == '2':
                        print("[INFO] 프레임 스킵 조절 - 기본값(2) 유지")
                    elif choice == '3':
                        print("[INFO] 해상도 조절 - 기본값(640x480) 유지")
                    elif choice == '4':
                        print("[INFO] 얼굴 인식 간격 조절 - 기본값(30) 유지")
                    elif choice == '5':
                        print("[INFO] YOLO 감지 간격 조절 - 기본값(10) 유지")
                    elif choice == '6':
                        self.config.performance_config.enable_gpu = not self.config.performance_config.enable_gpu
                        print(f"[INFO] GPU 가속: {'ON' if self.config.performance_config.enable_gpu else 'OFF'}")
                    
                    self.performance_mode = False
                    self.input_active = False
                    self.input_buffer = ""
                    return True
                elif self.clear_mode:
                    confirm = self.input_buffer.strip().lower()
                    if confirm == 'y':
                        self.driver_thresholds.clear()
                        self.driver_baselines.clear()
                        self.identification_status = "Database Cleared"
                        print("[INFO] 데이터베이스가 초기화되었습니다.")
                    else:
                        print("[INFO] 데이터베이스 초기화 취소됨")
                    
                    self.clear_mode = False
                    self.input_active = False
                    self.input_buffer = ""
                    return True
            else:
                # 빈 입력이면 입력 모드 종료
                self.input_active = False
                self.registration_mode = False
                self.baseline_mode = False
                self.performance_mode = False
                self.clear_mode = False
                self.input_buffer = ""
                print("[INFO] 입력 취소됨")
                return True
        elif key == 8:  # Backspace
            if self.input_buffer:
                self.input_buffer = self.input_buffer[:-1]
                return True
        elif 32 <= key <= 126:  # Printable ASCII characters
            self.input_buffer += chr(key)
            return True
        
        return False
    
    def process_pending_registration(self, frame: np.ndarray):
        """대기 중인 등록 처리"""
        if hasattr(self, 'pending_registration') and self.pending_registration:
            user_name = self.pending_registration
            if self.face_processor.register_driver_face(frame, user_name):
                self.identification_status = f"Registered: {user_name}"
                print(f"[SUCCESS] 사용자 등록 완료: {user_name}")
            else:
                self.identification_status = "Registration Failed"
                print(f"[ERROR] 사용자 등록 실패: {user_name}")
            self.pending_registration = None
    
    def __del__(self):
        """소멸자"""
        self.cleanup()

def show_automation_info():
    """자동화 시스템 정보 표시"""
    print("\n" + "="*60)
    print("🤖 ADVANCED DRIVER MONITORING SYSTEM v2.0")
    print("="*60)
    print("✅ 클래스 기반 아키텍처")
    print("✅ 설정 파일 관리 시스템")
    print("✅ 성능 최적화 및 모니터링")
    print("✅ 비동기 YOLO 객체 감지")
    print("✅ 강화된 오류 처리")
    print("✅ 실시간 FPS 측정")
    print("✅ 개인별 임계치 자동 관리")
    print("✅ 자동화된 운전자 인식")
    print("✅ 로깅 시스템")
    print("✅ 다중 각도 얼굴 등록")
    print("✅ 엄격한 얼굴 인식")
    print("✅ 테스트 모드")
    print("")
    print("🚗 DRIVER AUTOMATION:")
    print("✅ 자동 운전자 인식 및 전환")
    print("✅ 개인별 임계치 자동 적용")
    print("✅ 베이스라인 측정 시간 조절")
    print("✅ 성능 설정 실시간 조절")
    print("✅ 멀티스레드 처리")
    print("="*60)

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
    
    monitor = DriverMonitor("config.json")
    
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
            if monitor.face_processor.register_driver_face(frame, "test_user"):
                print("Face registered successfully!")
            else:
                print("Face registration failed!")
        elif key == ord('i'):
            result = monitor.face_processor.identify_driver(frame)
            if result and result not in ["No Face", "Multiple Faces", "Encoding Failed", "No Registered", "Unknown Driver", "Identification Error", "Uncertain"]:
                print(f"Identified: {result}")
            else:
                print(f"Identification failed: {result}")
    
    cap.release()
    cv2.destroyAllWindows()

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
    print("python driver_monitor_v2.py --face_threshold 0.45")
    print("python driver_monitor_v2.py --test_mode  # 테스트 모드")

def show_help():
    """도움말 표시"""
    print("\n=== 고급 운전자 모니터링 시스템 도움말 ===")
    print("🚗 자동화 기능:")
    print("   - 시스템 시작 시 자동 운전자 인식")
    print("   - 개인별 임계치 자동 적용")
    print("   - 새로운 운전자 자동 감지")
    print("   - 실시간 성능 모니터링")
    print("")
    print("📝 수동 조작:")
    print("R: 얼굴 등록")
    print("I: 얼굴 식별")
    print("B: Baseline 측정 (시간 선택 가능)")
    print("N: 새 사용자 등록 (10분간 개인 임계치 측정)")
    print("P: 성능 설정 조절")
    print("S: 설정 저장")
    print("L: 설정 로드")
    print("+/-: 감도 조절")
    print("C: 데이터베이스 초기화")
    print("H: 도움말")
    print("ESC: 종료")
    print("")
    print("⚡ 성능 최적화:")
    print("   - 프레임 스킵: 처리량 조절")
    print("   - 해상도: 320x240 ~ 1280x720")
    print("   - 얼굴 인식: 10-60프레임마다")
    print("   - YOLO 감지: 5-30프레임마다")
    print("   - GPU 가속: CUDA 지원")
    print("")
    print("🔧 고급 기능:")
    print("   - 설정 파일 자동 저장/로드")
    print("   - 실시간 FPS 모니터링")
    print("   - 비동기 객체 감지")
    print("   - 강화된 오류 처리")
    print("   - 로그 파일 생성")
    print("================================")

def run_driver_monitoring_system():
    """메인 실행 함수"""
    try:
        # 명령행 인수 파싱
        parser = argparse.ArgumentParser(description='Driver Monitoring System')
        parser.add_argument('--test_mode', action='store_true', help='Run in test mode')
        parser.add_argument('--gpu', action='store_true', help='Enable GPU acceleration')
        args = parser.parse_args()
        
        # 테스트 모드인 경우 얼굴 인식 정확도 테스트 실행
        if args.test_mode:
            test_face_recognition_accuracy()
            return
        
        # 시스템 정보 표시
        show_automation_info()
        
        # DriverMonitor 인스턴스 생성
        monitor = DriverMonitor("config.json")
        
        # Jetson 최적화 초기화
        monitor.initialize_jetson_optimization()
        
        # 카메라 초기화
        if not monitor.initialize_camera():
            logging.error("카메라 초기화 실패")
            return
        
        # 운전자 데이터 로드
        monitor.load_driver_data()
        
        # 자동 초기화 체크
        registered_faces = monitor.face_processor.load_registered_faces()
        baseline_exists = os.path.exists(monitor.config.path_config.baseline_path)
        
        # 첫 실행 시 자동 Owner 등록 준비
        if not registered_faces:
            print("[INFO] No registered faces found. First user will be registered as Owner automatically.")
        
        # 베이스라인이 없으면 자동 베이스라인 측정 시작
        if not baseline_exists and monitor.config.auto_setup_config.auto_baseline_measurement:
            print("[INFO] No baseline found. Waiting for first driver to start auto baseline measurement...")
            # 첫 번째 운전자가 인식되면 자동으로 베이스라인 측정 시작
            monitor.auto_baseline_waiting = True
        
        # 화면 해상도 가져오기
        screen_width = int(monitor.cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        screen_height = int(monitor.cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        
        logging.info(f"화면 해상도: {screen_width}x{screen_height}")
        
        print("\n[INFO] 시스템이 시작되었습니다.")
        print("[INFO] 'H' 키를 눌러 도움말을 확인하세요.")
        
        while True:
            # 프레임 읽기
            ret, frame = monitor.cap.read()
            if not ret:
                logging.error("프레임을 읽을 수 없습니다")
                break
            
            # 프레임 처리
            result = monitor.process_frame(frame)
            
            # 대기 중인 등록 처리
            monitor.process_pending_registration(frame)
            
            # 화면 하단에 정보 표시
            cv2.putText(frame, f"Current Driver: {monitor.current_driver or 'None'}", 
                       (50, screen_height - 150), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)
            cv2.putText(frame, f"ID Status: {monitor.identification_status}", 
                       (50, screen_height - 120), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)
            
            # 베이스라인 측정 중이면 진행률 표시
            if monitor.baseline_measurement_active:
                elapsed_time = time.time() - monitor.baseline_start_time
                progress = int((elapsed_time / monitor.baseline_duration) * 100)
                remaining_time = int(monitor.baseline_duration - elapsed_time)
                
                cv2.putText(frame, f"BASELINE MEASUREMENT: {progress}% ({remaining_time}s remaining)", 
                           (50, screen_height - 90), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
                cv2.putText(frame, f"Driver: {monitor.current_driver or 'Unknown'}", 
                           (50, screen_height - 70), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 1)
                cv2.putText(frame, "Please stay still and look forward", 
                           (50, screen_height - 50), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 1)
            else:
                # 현재 임계치 정보 표시
                if monitor.current_driver:
                    thresholds = monitor.config.detection_thresholds
                    cv2.putText(frame, f"Thresholds - EAR:{thresholds.eye_ar_thresh:.3f} Yaw:{thresholds.yaw_thresh:.1f} Roll:{thresholds.roll_thresh:.1f}", 
                               (50, screen_height - 90), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 1)
                    
                    # 개인별 임계치 사용 여부 표시
                    if monitor.current_driver in monitor.driver_thresholds:
                        cv2.putText(frame, f"Personal Thresholds: ON ({monitor.current_driver})", 
                                   (50, screen_height - 70), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 1)
                    else:
                        cv2.putText(frame, f"Personal Thresholds: OFF (Default)", 
                                   (50, screen_height - 70), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 1)
                else:
                    cv2.putText(frame, "No Driver Detected", 
                               (50, screen_height - 90), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 1)
            
            # 성능 정보 표시
            perf_info = monitor.performance_monitor.get_performance_info()
            perf_color = (0, 255, 0) if monitor.config.performance_config.performance_mode else (0, 0, 255)
            cv2.putText(frame, f"Performance: {'ON' if monitor.config.performance_config.performance_mode else 'OFF'}", 
                       (50, screen_height - 50), cv2.FONT_HERSHEY_SIMPLEX, 0.6, perf_color, 1)
            cv2.putText(frame, f"FPS: {perf_info['fps']:.1f} | Skip:{monitor.config.performance_config.skip_frames}", 
                       (50, screen_height - 30), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)
            
            # 입력 상태 표시
            if monitor.input_active:
                input_text = ""
                if monitor.registration_mode:
                    input_text = f"Enter name: {monitor.input_buffer}_"
                elif monitor.baseline_mode:
                    input_text = f"Baseline option (1-4): {monitor.input_buffer}_"
                elif monitor.performance_mode:
                    input_text = f"Performance option (1-6): {monitor.input_buffer}_"
                elif monitor.clear_mode:
                    input_text = f"Confirm clear (y/N): {monitor.input_buffer}_"
                
                # 입력 텍스트를 화면 중앙에 표시 (긴 이름 지원)
                text_x = max(50, screen_width//2 - len(input_text) * 15)  # 텍스트 길이에 따라 위치 조정
                cv2.putText(frame, input_text, 
                           (text_x, screen_height//2), 
                           cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 255), 2)
                cv2.putText(frame, "Press Enter to confirm, ESC to cancel", 
                           (text_x, screen_height//2 + 40), 
                           cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 1)
            
            # 조작 가이드
            cv2.putText(frame, "R:Register I:Identify B:Baseline N:New User P:Performance S:Save L:Load +/-:Sensitivity C:Clear H:Help ESC:Exit", 
                       (50, screen_height - 20), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
            
            # 터미널 메시지 출력
            if result['success'] and result.get('terminal_messages'):
                for msg in result['terminal_messages']:
                    print(f"[{time.strftime('%H:%M:%S', time.localtime())}] {msg}")
            
            # 화면에 프레임 표시
            cv2.imshow('Advanced Driver Monitoring System v2.0', frame)
            
            # 키 입력 처리
            key = cv2.waitKey(5) & 0xFF
            if key == 27:  # ESC
                break
            elif key == ord('h'):  # 도움말
                show_help()
            elif key == ord('r'):  # 얼굴 등록
                print("\n[INFO] 얼굴 등록 모드 활성화")
                print("[INFO] 화면에서 사용자 이름을 입력하세요 (Enter로 완료)")
                monitor.registration_mode = True
                monitor.input_active = True
                monitor.input_buffer = ""
            elif monitor.handle_async_input(key):  # 비동기 입력 처리
                continue
            elif key == ord('i'):  # 얼굴 식별
                identified_name = monitor.face_processor.identify_driver(frame)
                monitor.identification_status = identified_name
                print(f"[INFO] 식별 결과: {identified_name}")
            elif key == ord('b'):  # 베이스라인 측정
                print("\n[INFO] 베이스라인 측정 모드 활성화")
                print("[INFO] 화면에서 옵션을 선택하세요 (1-4)")
                monitor.baseline_mode = True
                monitor.input_active = True
                monitor.input_buffer = ""
                monitor.baseline_prompt = "베이스라인 측정 옵션 (1-4): "
            elif key == ord('p'):  # 성능 설정
                print("\n[INFO] 성능 설정 모드 활성화")
                print("[INFO] 화면에서 옵션을 선택하세요 (1-6)")
                monitor.performance_mode = True
                monitor.input_active = True
                monitor.input_buffer = ""
                monitor.performance_prompt = "성능 설정 옵션 (1-6): "
            elif key == ord('s'):  # 설정 저장
                monitor.config.save_config()
                print("[INFO] 설정이 저장되었습니다.")
            elif key == ord('l'):  # 설정 로드
                monitor.config.load_config()
                print("[INFO] 설정이 로드되었습니다.")
            elif key == ord('+') or key == ord('='):  # 감도 증가
                monitor.config.detection_thresholds.eye_ar_thresh *= 0.9
                monitor.config.detection_thresholds.pitch_down_thresh *= 0.9
                monitor.config.detection_thresholds.yaw_thresh *= 0.9
                monitor.config.detection_thresholds.roll_thresh *= 0.9
                print(f"[INFO] 감도 증가: EAR={monitor.config.detection_thresholds.eye_ar_thresh:.3f}")
            elif key == ord('-') or key == ord('_'):  # 감도 감소
                monitor.config.detection_thresholds.eye_ar_thresh *= 1.1
                monitor.config.detection_thresholds.pitch_down_thresh *= 1.1
                monitor.config.detection_thresholds.yaw_thresh *= 1.1
                monitor.config.detection_thresholds.roll_thresh *= 1.1
                print(f"[INFO] 감도 감소: EAR={monitor.config.detection_thresholds.eye_ar_thresh:.3f}")
            elif key == ord('c'):  # 데이터베이스 초기화
                print("\n[INFO] 데이터베이스 초기화 모드 활성화")
                print("[INFO] 화면에서 확인하세요 (y/N)")
                monitor.clear_mode = True
                monitor.input_active = True
                monitor.input_buffer = ""
                monitor.clear_prompt = "정말로 모든 데이터를 삭제하시겠습니까? (y/N): "
        
        # 리소스 정리
        monitor.cleanup()
        print("\n[INFO] 시스템이 종료되었습니다.")
        
    except KeyboardInterrupt:
        print("\n[INFO] 사용자에 의해 중단되었습니다.")
    except Exception as e:
        logging.error(f"시스템 실행 중 오류 발생: {e}")
        print(f"\n[ERROR] 시스템 오류: {e}")
    finally:
        cv2.destroyAllWindows()

if __name__ == "__main__":
    run_driver_monitoring_system()
