#!/usr/bin/env python3
"""
Driver Monitoring System Dependencies Installer
자동으로 필요한 라이브러리들을 설치합니다.
"""

import subprocess
import sys
import os

def install_package(package):
    """패키지를 설치합니다."""
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", package])
        print(f"✅ {package} 설치 완료")
        return True
    except subprocess.CalledProcessError:
        print(f"❌ {package} 설치 실패")
        return False

def check_package(package):
    """패키지가 설치되어 있는지 확인합니다."""
    try:
        __import__(package)
        print(f"✅ {package} 이미 설치됨")
        return True
    except ImportError:
        print(f"⚠️  {package} 설치 필요")
        return False

def install_from_requirements():
    """requirements.txt 파일에서 패키지를 설치합니다."""
    requirements_file = "data/requirements.txt"
    if os.path.exists(requirements_file):
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install", "-r", requirements_file])
            print("✅ requirements.txt에서 패키지 설치 완료")
            return True
        except subprocess.CalledProcessError:
            print("❌ requirements.txt에서 패키지 설치 실패")
            return False
    else:
        print(f"⚠️  {requirements_file} 파일을 찾을 수 없습니다.")
        return False

def main():
    print("🚗 Driver Monitoring System 의존성 설치")
    print("=" * 50)
    
    # requirements.txt 파일이 있으면 먼저 시도
    if os.path.exists("data/requirements.txt"):
        print("\n📦 requirements.txt 파일에서 설치 시도...")
        if install_from_requirements():
            print("\n🎉 requirements.txt 설치 완료!")
            return
    
    # 수동 설치 (fallback)
    print("\n📦 수동 설치 모드...")
    
    # 설치할 패키지 목록
    packages = [
        "numpy>=1.20.0",
        "scipy>=1.5.0", 
        "opencv-python>=4.5.0",
        "ultralytics>=8.0.0",
        "mediapipe>=0.10.0",
        "face-recognition>=1.3.0",
        "scikit-learn>=1.0.0",
        "Pillow>=9.0.0"
    ]
    
    # 패키지별 설치 상태 확인
    print("\n📦 패키지 설치 상태 확인...")
    missing_packages = []
    
    for package in packages:
        package_name = package.split('>=')[0].split('==')[0]
        if not check_package(package_name):
            missing_packages.append(package)
    
    if not missing_packages:
        print("\n🎉 모든 패키지가 이미 설치되어 있습니다!")
        return
    
    # 누락된 패키지 설치
    print(f"\n📥 {len(missing_packages)}개 패키지 설치 중...")
    failed_packages = []
    
    for package in missing_packages:
        if not install_package(package):
            failed_packages.append(package)
    
    # 설치 결과 요약
    print("\n" + "=" * 50)
    if failed_packages:
        print(f"❌ {len(failed_packages)}개 패키지 설치 실패:")
        for package in failed_packages:
            print(f"   - {package}")
        print("\n💡 해결 방법:")
        print("1. pip 업그레이드: python -m pip install --upgrade pip")
        print("2. Visual Studio Build Tools 설치 (Windows)")
        print("3. cmake 설치 (Linux/macOS)")
    else:
        print("🎉 모든 패키지 설치 완료!")
    
    print("\n📝 설치 노트:")
    print("- dlib (face-recognition 의존성)은 추가 시스템 의존성이 필요할 수 있습니다")
    print("- Windows: Visual Studio Build Tools 필요")
    print("- Linux: sudo apt-get install cmake build-essential")
    print("- macOS: brew install cmake")

if __name__ == "__main__":
    main()
