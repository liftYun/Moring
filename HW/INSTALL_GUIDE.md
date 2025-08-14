# 운전자 모니터링 시스템 설치 가이드

## 필수 요구사항
- Windows 10/11
- Python 3.8-3.12
- 웹캠

## 1단계: Miniconda 설치

### 1.1 Miniconda 다운로드
- [Miniconda 다운로드 페이지](https://docs.conda.io/en/latest/miniconda.html) 방문
- Windows 64-bit 버전 다운로드

### 1.2 Miniconda 설치
1. 다운로드한 파일 실행
2. **중요**: "Add Miniconda3 to my PATH environment variable" 체크
3. "Install for all users" 선택 (권장)
4. 설치 완료

### 1.3 설치 확인
```bash
# 새 명령 프롬프트 열고
conda --version
```

## 2단계: 자동 설치 (권장)

### 방법 1: 배치 파일 사용
```bash
# install.bat 파일 더블클릭
```

### 방법 2: 수동 설치
```bash
# 1. conda 패키지 설치
conda install -c conda-forge dlib face-recognition -y

# 2. 나머지 패키지 설치
pip install -r requirements.txt
```

## 3단계: 실행
```bash
python driver_monitor_v2.py
```

## 문제 해결

### conda 명령어가 인식되지 않는 경우
1. 명령 프롬프트 재시작
2. 또는 Anaconda Prompt 사용

### 설치 중 오류 발생
```bash
# conda 환경 새로 생성
conda create -n driver_monitor python=3.12
conda activate driver_monitor

# 다시 설치
conda install -c conda-forge dlib face-recognition -y
pip install -r requirements.txt
```

### GPU 사용 시
```bash
# CUDA 지원 PyTorch 설치
conda install pytorch torchvision pytorch-cuda=12.1 -c pytorch -c nvidia
```


