#!/bin/bash

echo "🚀 Jetson 성능 최적화 시작..."

# 1. 최대 성능 모드로 설정
echo "📈 최대 성능 모드로 설정..."
sudo nvpmodel -m 0  # 최대 성능 모드
sudo jetson_clocks  # Jetson 클럭 활성화

# 2. GPU 메모리 설정
echo "🎮 GPU 메모리 설정..."
echo 0 > /sys/devices/gpu.0/devfreq/17000000.gv11b/governor
echo 1 > /sys/devices/gpu.0/devfreq/17000000.gv11b/userspace/set_freq

# 3. CPU 성능 설정
echo "⚡ CPU 성능 설정..."
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# 4. 메모리 설정
echo "💾 메모리 설정..."
echo 0 > /proc/sys/vm/swappiness

# 5. 네트워크 설정
echo "🌐 네트워크 설정..."
sudo ethtool -s eth0 speed 1000 duplex full autoneg off

# 6. USB 카메라 최적화
echo "📷 USB 카메라 최적화..."
sudo modprobe uvcvideo timeout=5000 quirks=0x80

# 7. 시스템 설정
echo "🔧 시스템 설정..."
echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf
echo 'fs.file-max=524288' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# 8. 현재 상태 확인
echo "📊 현재 상태 확인..."
echo "=== Jetson 상태 ==="
nvpmodel -q
echo "=== GPU 상태 ==="
cat /sys/devices/gpu.0/devfreq/17000000.gv11b/cur_freq
echo "=== CPU 상태 ==="
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor | head -1
echo "=== 메모리 상태 ==="
free -h

echo "✅ Jetson 성능 최적화 완료!"
echo "💡 이제 driver_monitor_jetson.py를 실행하세요!"
