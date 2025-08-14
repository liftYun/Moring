#!/usr/bin/env python3
"""
승인 요청 상태 확인 스크립트
라즈베리파이에서 승인 요청이 오는지 확인하는 간단한 도구
"""

import os
import json
import time
from datetime import datetime

def check_approval_requests():
    """승인 요청 상태 확인"""
    approval_dir = "./approval_requests"
    
    if not os.path.exists(approval_dir):
        print("❌ approval_requests 디렉토리가 없습니다.")
        print("승인 수신기가 실행되지 않았거나 설치되지 않았습니다.")
        return
    
    # 파일 목록 가져오기
    files = os.listdir(approval_dir)
    
    if not files:
        print("📭 승인 요청이 아직 없습니다.")
        print("젯슨에서 미등록자를 감지하면 여기에 파일이 생성됩니다.")
        return
    
    print(f"📁 승인 요청 디렉토리: {approval_dir}")
    print(f"📊 총 {len(files)}개의 파일이 있습니다.")
    print()
    
    # 최근 5개 파일만 표시
    recent_files = sorted(files, key=lambda x: os.path.getmtime(os.path.join(approval_dir, x)), reverse=True)[:5]
    
    print("🕒 최근 승인 요청들:")
    print("-" * 60)
    
    for i, filename in enumerate(recent_files, 1):
        filepath = os.path.join(approval_dir, filename)
        file_time = datetime.fromtimestamp(os.path.getmtime(filepath))
        
        if filename.endswith('.jpg'):
            print(f"{i}. 📸 {filename}")
            print(f"   시간: {file_time.strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"   타입: 이미지 파일")
        elif filename.endswith('.json'):
            print(f"{i}. 📄 {filename}")
            print(f"   시간: {file_time.strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"   타입: 요청 정보")
            
            # JSON 파일 내용 읽기
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    print(f"   VIN: {data.get('vin', 'N/A')}")
                    print(f"   SessionID: {data.get('session_id', 'N/A')}")
            except:
                print(f"   내용: 읽기 실패")
        
        print()

def monitor_approval_requests():
    """실시간 모니터링"""
    approval_dir = "./approval_requests"
    
    if not os.path.exists(approval_dir):
        print("❌ approval_requests 디렉토리가 없습니다.")
        return
    
    print("🔍 실시간 승인 요청 모니터링 시작...")
    print("젯슨에서 미등록자를 감지하면 여기에 알림이 표시됩니다.")
    print("Ctrl+C로 종료할 수 있습니다.")
    print("-" * 60)
    
    # 초기 파일 개수
    initial_count = len(os.listdir(approval_dir))
    
    try:
        while True:
            current_count = len(os.listdir(approval_dir))
            
            if current_count > initial_count:
                print(f"🚨 새로운 승인 요청 감지! ({current_count - initial_count}개 추가)")
                print(f"시간: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
                print("-" * 60)
                initial_count = current_count
            
            time.sleep(1)
            
    except KeyboardInterrupt:
        print("\n모니터링을 종료합니다.")

def main():
    """메인 함수"""
    print("🚗 승인 요청 상태 확인")
    print("1. 현재 상태 확인")
    print("2. 실시간 모니터링")
    print("3. 종료")
    
    while True:
        choice = input("\n선택하세요 (1-3): ")
        
        if choice == "1":
            check_approval_requests()
        elif choice == "2":
            monitor_approval_requests()
        elif choice == "3":
            print("종료합니다.")
            break
        else:
            print("잘못된 선택입니다.")

if __name__ == "__main__":
    main()
