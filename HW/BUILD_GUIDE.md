# 운전자 모니터링 시스템 빌드 가이드

## 📋 필수 요구사항
- **운영체제**: Windows 10/11 (64-bit)
- **Python**: 3.12.10 (확인됨)
- **웹캠**: USB 또는 내장 웹캠
- **메모리**: 최소 4GB RAM (8GB 권장)
- **저장공간**: 최소 2GB 여유 공간

## 🚀 간단한 설치 (확인됨)

### 1단계: Python 설치 확인
```bash
python --version
```
- Python 3.12.10이 설치되어 있어야 함
- 설치되지 않은 경우: [Python 공식 사이트](https://www.python.org/downloads/)에서 다운로드
- 설치 시 **"Add Python to PATH"** 체크 필수!

### 2단계: 자동 설치
```bash
# install_simple.bat 파일 더블클릭
```

### 3단계: 수동 설치 (자동 설치 실패 시)
```bash
# 1. pip 업그레이드
python -m pip install --upgrade pip

# 2. 모든 패키지 설치
pip install -r requirements.txt

# 3. 설치 확인
python -c "import cv2, dlib, face_recognition, mediapipe, torch, ultralytics; print('SUCCESS!')"
```

### 4단계: 실행
```bash
python driver_monitor_v2.py
```

## 🔧 문제 해결

### dlib 설치 실패 (가장 흔한 문제)
**오류**: "CMake is not installed" 또는 "Failed building wheel for dlib"

**해결 방법**:

#### 방법 1: Visual Studio Build Tools + CMake 설치
1. **Visual Studio Build Tools 설치**:
   - [다운로드](https://visualstudio.microsoft.com/visual-cpp-build-tools/)
   - 설치 시 "C++ build tools" 선택
2. **CMake 설치**:
   - [다운로드](https://cmake.org/download/)
   - 설치 시 "Add CMake to PATH" 선택
3. **컴퓨터 재시작**
4. **다시 설치**:
   ```bash
   pip install dlib==20.0.0
   pip install face-recognition==1.3.0
   ```

#### 방법 2: conda 사용
```bash
# conda로 dlib 설치 (빌드 도구 불필요)
conda install -c conda-forge dlib face-recognition -y
```

#### 방법 3: 미리 컴파일된 wheel 사용
```bash
# Python 3.12용 미리 컴파일된 dlib
pip install https://github.com/jloh02/dlib/releases/download/v19.22/dlib-19.22.99-cp312-cp312-win_amd64.whl
pip install face-recognition==1.3.0
```

### Python 버전 문제
```bash
# Python 3.12.10이 아닌 경우
# Python 3.12.10으로 업그레이드 또는 다운그레이드
```

### pip 설치 실패
```bash
# pip 업그레이드
python -m pip install --upgrade pip

# 개별 패키지 설치
pip install opencv-python==4.11.0.86
pip install dlib==20.0.0
pip install face-recognition==1.3.0
```

### GPU 사용 시
```bash
# CUDA 지원 PyTorch는 자동으로 설치됨
# torch==2.5.1+cu121, torchvision==0.20.1+cu121
```

## 📁 프로젝트 구조
```
HW/
├── driver_monitor_v2.py    # 메인 프로그램
├── requirements.txt        # 의존성 목록 (확인됨)
├── install_simple.bat     # 자동 설치 스크립트
├── install_manual.bat     # 수동 설치 가이드
├── BUILD_GUIDE.md         # 이 파일
├── config.json            # 설정 파일 (자동 생성)
├── data/                  # 데이터 폴더
│   ├── registered_faces.json
│   ├── driver_thresholds.json
│   └── baseline.json
└── models/                # AI 모델
    └── best.pt           # YOLO 모델
```

## 🎯 사용법
1. **실행**: `python driver_monitor_v2.py`
2. **사용자 등록**: `r` 키 → 이름 입력
3. **베이스라인 측정**: `b` 키 → 옵션 선택
4. **성능 설정**: `p` 키 → 옵션 선택
5. **종료**: `q` 키

## 📞 추가 도움
- **로그 파일**: `driver_monitor.log` 확인
- **설정 파일**: `config.json` 수정
- **문제 발생**: 로그 메시지 확인 후 재설치
- **dlib 문제**: `install_manual.bat` 실행하여 수동 설치 가이드 참조

---
**💡 팁**: dlib 설치가 가장 어려운 부분입니다. conda 사용을 권장합니다!
