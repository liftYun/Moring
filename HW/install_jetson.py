#!/usr/bin/env python3
"""
Jetson 전용 Driver Monitoring System 설치 스크립트
Jetson Nano/Xavier/Orin에 최적화된 설치
"""

import subprocess
import sys
import os
import platform

def run_command(command, description):
    """명령어를 실행하고 결과를 출력합니다."""
    print(f"\n🔧 {description}...")
    try:
        result = subprocess.run(command, shell=True, check=True, capture_output=True, text=True)
        print(f"✅ {description} 완료")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ {description} 실패: {e}")
        print(f"오류 출력: {e.stderr}")
        return False

def check_jetson():
    """Jetson 환경인지 확인합니다."""
    print("🔍 Jetson 환경 확인 중...")
    
    # Jetson 확인
    try:
        with open('/proc/device-tree/model', 'r') as f:
            model = f.read().strip()
            if 'jetson' in model.lower():
                print(f"✅ Jetson 감지: {model}")
                return True
    except:
        pass
    
    # ARM 아키텍처 확인
    if platform.machine() == 'aarch64':
        print("✅ ARM64 아키텍처 감지 (Jetson 가능)")
        return True
    
    print("⚠️  Jetson이 아닌 환경입니다. 일반 설치를 권장합니다.")
    return False

def install_system_dependencies():
    """시스템 의존성을 설치합니다."""
    commands = [
        ("sudo apt-get update", "패키지 목록 업데이트"),
        ("sudo apt-get install -y python3-opencv", "OpenCV 설치"),
        ("sudo apt-get install -y cmake build-essential", "빌드 도구 설치"),
        ("sudo apt-get install -y libblas-dev liblapack-dev", "BLAS/LAPACK 설치"),
        ("sudo apt-get install -y libatlas-base-dev", "ATLAS 설치"),
        ("sudo apt-get install -y libx11-dev libgtk-3-dev", "GUI 라이브러리 설치"),
        ("sudo apt-get install -y libavcodec-dev libavformat-dev libswscale-dev", "비디오 코덱 설치")
    ]
    
    for command, description in commands:
        if not run_command(command, description):
            return False
    return True

def install_python_dependencies():
    """Python 의존성을 설치합니다."""
    commands = [
        ("pip3 install numpy>=1.20.0", "NumPy 설치"),
        ("pip3 install scipy>=1.5.0", "SciPy 설치"),
        ("pip3 install ultralytics>=8.0.0", "Ultralytics 설치"),
        ("pip3 install mediapipe>=0.10.0", "MediaPipe 설치"),
        ("pip3 install scikit-learn>=1.0.0", "scikit-learn 설치"),
        ("pip3 install Pillow>=9.0.0", "Pillow 설치")
    ]
    
    for command, description in commands:
        if not run_command(command, description):
            return False
    return True

def install_dlib():
    """dlib을 Jetson에 맞게 설치합니다."""
    print("\n🔧 dlib 설치 (Jetson 최적화)...")
    
    # dlib 소스 다운로드 (최신 버전)
    if not run_command("wget http://dlib.net/files/dlib-19.24.2.tar.bz2", "dlib 소스 다운로드"):
        return False
    
    # 압축 해제
    if not run_command("tar -xf dlib-19.24.2.tar.bz2", "dlib 압축 해제"):
        return False
    
    # dlib 디렉토리로 이동
    os.chdir("dlib-19.24.2")
    
    # Jetson Orin Nano 최적화 옵션으로 컴파일
    cmake_command = (
        "cmake -DCMAKE_BUILD_TYPE=Release "
        "-DUSE_AVX_INSTRUCTIONS=0 "     # ARM64에서는 AVX 미지원
        "-DUSE_SSE4_INSTRUCTIONS=OFF "  # ARM에서는 SSE4 사용 불가
        "-DUSE_SSE2_INSTRUCTIONS=OFF "  # ARM에서는 SSE2 사용 불가
        "-DUSE_SSE_INSTRUCTIONS=OFF "   # ARM에서는 SSE 사용 불가
        "-DUSE_NEON_INSTRUCTIONS=ON "   # ARM NEON 사용
        "-DUSE_BLAS=ON "
        "-DUSE_LAPACK=ON "
        "-DUSE_CUDA=ON "                # CUDA 사용
        "-DCUDA_ARCH_BIN=8.7 "          # Jetson Orin Nano 아키텍처
        "-DCUDA_ARCH_PTX=8.7 "          # Jetson Orin Nano 아키텍처
        "."
    )
    
    if not run_command(cmake_command, "dlib CMake 설정"):
        return False
    
    # 컴파일 (시간이 오래 걸림)
    if not run_command("make -j4", "dlib 컴파일"):
        return False
    
    # 설치
    if not run_command("sudo make install", "dlib 설치"):
        return False
    
    # Python 바인딩 설치
    if not run_command("sudo python3 setup.py install", "dlib Python 바인딩 설치"):
        return False
    
    # 상위 디렉토리로 돌아가기
    os.chdir("..")
    
    # 정리
    run_command("rm -rf dlib-19.24.2*", "임시 파일 정리")
    
    return True

def install_face_recognition():
    """face_recognition 설치"""
    print("\n🔧 face_recognition 설치...")
    return run_command("pip3 install face-recognition", "face_recognition 설치")

def main():
    print("🚗 Jetson Driver Monitoring System 설치")
    print("=" * 60)
    
    # Jetson 환경 확인
    if not check_jetson():
        print("\n💡 일반 환경에서는 install_dependencies.py를 사용하세요.")
        return
    
    print("\n📦 Jetson 전용 설치 시작...")
    
    # 1. 시스템 의존성 설치
    if not install_system_dependencies():
        print("\n❌ 시스템 의존성 설치 실패")
        return
    
    # 2. Python 의존성 설치
    if not install_python_dependencies():
        print("\n❌ Python 의존성 설치 실패")
        return
    
    # 3. dlib 설치 (가장 어려운 부분)
    print("\n⚠️  dlib 설치를 시작합니다. (30분-1시간 소요)")
    if not install_dlib():
        print("\n❌ dlib 설치 실패")
        print("💡 대안: pip3 install dlib --no-cache-dir")
        return
    
    # 4. face_recognition 설치
    if not install_face_recognition():
        print("\n❌ face_recognition 설치 실패")
        return
    
    print("\n" + "=" * 60)
    print("🎉 Jetson 설치 완료!")
    print("\n📝 다음 단계:")
    print("1. 웹캠 연결 확인")
    print("2. python3 v1ai_model_modified.py 실행")
    print("3. 성능 모니터링: nvidia-smi")
    
    print("\n💡 성능 최적화 팁:")
    print("- Jetson 전용 모드: sudo nvpmodel -m 0")
    print("- 팬 속도 조절: sudo jetson_clocks")
    print("- 메모리 모니터링: htop")

if __name__ == "__main__":
    main()
