# 라즈베리파이 MQTT 브로커 설정 가이드

## 1. Mosquitto MQTT 브로커 설치

```bash
# 패키지 업데이트
sudo apt update

# Mosquitto 브로커 및 클라이언트 설치
sudo apt install mosquitto mosquitto-clients

# 서비스 활성화 및 시작
sudo systemctl enable mosquitto
sudo systemctl start mosquitto
```

## 2. Mosquitto 설정

### 설정 파일 생성
```bash
sudo nano /etc/mosquitto/conf.d/default.conf
```

### 설정 내용
```conf
# 기본 포트 설정
listener 1883
protocol mqtt

# WebSocket 포트 (웹 클라이언트용)
listener 9001
protocol websockets

# 익명 접근 비활성화
allow_anonymous false

# 비밀번호 파일 설정
password_file /etc/mosquitto/passwd

# 로그 설정
log_type all
log_dest file /var/log/mosquitto/mosquitto.log
log_dest stdout

# 연결 제한
max_connections 100
max_inflight_messages 20

# 지속성 설정
persistence true
persistence_location /var/lib/mosquitto/

# 보안 설정
# SSL/TLS 사용 시 (선택사항)
# listener 8883
# cafile /etc/mosquitto/certs/ca.crt
# certfile /etc/mosquitto/certs/server.crt
# keyfile /etc/mosquitto/certs/server.key
```

## 3. 사용자 계정 생성

### 비밀번호 파일 생성
```bash
# 비밀번호 파일 생성
sudo mosquitto_passwd -c /etc/mosquitto/passwd moring

# 비밀번호 입력: kimoring

# 파일 권한 설정
sudo chmod 644 /etc/mosquitto/passwd
```

## 4. 방화벽 설정

```bash
# UFW 활성화
sudo ufw enable

# MQTT 포트 허용
sudo ufw allow 1883

# WebSocket 포트 허용 (선택사항)
sudo ufw allow 9001

# SSH 포트 허용 (원격 접속용)
sudo ufw allow 22

# 방화벽 상태 확인
sudo ufw status
```

## 5. 서비스 재시작 및 확인

```bash
# Mosquitto 서비스 재시작
sudo systemctl restart mosquitto

# 서비스 상태 확인
sudo systemctl status mosquitto

# 로그 확인
sudo tail -f /var/log/mosquitto/mosquitto.log
```

## 6. 연결 테스트

### 로컬 테스트
```bash
# 구독자 실행 (터미널 1)
mosquitto_sub -h localhost -p 1883 -u moring -P kimoring -t "test/topic"

# 발행자 실행 (터미널 2)
mosquitto_pub -h localhost -p 1883 -u moring -P kimoring -t "test/topic" -m "Hello MQTT!"
```

### 원격 테스트
```bash
# 다른 기기에서 테스트
mosquitto_sub -h 192.168.10.3 -p 1883 -u moring -P kimoring -t "car/+/alert"
```

## 7. 자동 시작 설정

```bash
# 부팅 시 자동 시작 확인
sudo systemctl is-enabled mosquitto

# 자동 시작 활성화 (이미 위에서 설정됨)
sudo systemctl enable mosquitto
```

## 8. 모니터링 및 관리

### 실시간 연결 상태 확인
```bash
# 연결된 클라이언트 확인
sudo mosquitto_sub -h localhost -p 1883 -u moring -P kimoring -t '$SYS/broker/clients/connected' -C 1

# 구독 토픽 확인
sudo mosquitto_sub -h localhost -p 1883 -u moring -P kimoring -t '$SYS/broker/subscriptions/count' -C 1
```

### 로그 모니터링
```bash
# 실시간 로그 확인
sudo tail -f /var/log/mosquitto/mosquitto.log

# 특정 패턴 검색
sudo grep "Connection" /var/log/mosquitto/mosquitto.log
```

## 9. 성능 최적화 (선택사항)

### 고성능 설정
```conf
# /etc/mosquitto/conf.d/performance.conf
max_queued_messages 1000
max_inflight_messages 20
max_packet_size 268435455
message_size_limit 0
```

### 메모리 사용량 모니터링
```bash
# 메모리 사용량 확인
ps aux | grep mosquitto
free -h
```

## 10. 문제 해결

### 일반적인 문제들

1. **연결 거부**
   ```bash
   # 포트 확인
   sudo netstat -tlnp | grep 1883
   
   # 방화벽 확인
   sudo ufw status
   ```

2. **인증 실패**
   ```bash
   # 비밀번호 파일 확인
   sudo cat /etc/mosquitto/passwd
   
   # 사용자 재생성
   sudo mosquitto_passwd -c /etc/mosquitto/passwd moring
   ```

3. **서비스 시작 실패**
   ```bash
   # 서비스 상태 확인
   sudo systemctl status mosquitto
   
   # 설정 파일 문법 검사
   sudo mosquitto -c /etc/mosquitto/mosquitto.conf -t
   ```

### 로그 분석
```bash
# 오류 로그 확인
sudo grep "ERROR" /var/log/mosquitto/mosquitto.log

# 연결 로그 확인
sudo grep "Connection" /var/log/mosquitto/mosquitto.log
```

## 11. 보안 강화 (선택사항)

### SSL/TLS 설정
```bash
# 인증서 생성
sudo mkdir -p /etc/mosquitto/certs
cd /etc/mosquitto/certs

# 자체 서명 인증서 생성
sudo openssl req -new -x509 -days 365 -extensions v3_ca -keyout ca.key -out ca.crt
sudo openssl req -new -out server.csr -keyout server.key
sudo openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365
```

### SSL 설정 추가
```conf
# /etc/mosquitto/conf.d/ssl.conf
listener 8883
cafile /etc/mosquitto/certs/ca.crt
certfile /etc/mosquitto/certs/server.crt
keyfile /etc/mosquitto/certs/server.key
```

## 12. 백업 및 복구

### 설정 백업
```bash
# 설정 파일 백업
sudo cp /etc/mosquitto/mosquitto.conf /backup/
sudo cp -r /etc/mosquitto/conf.d/ /backup/
sudo cp /etc/mosquitto/passwd /backup/
```

### 데이터 백업
```bash
# 지속성 데이터 백업
sudo cp -r /var/lib/mosquitto/ /backup/
```

이제 라즈베리파이에서 MQTT 브로커가 설정되었습니다. 백엔드와 워치 앱이 이 브로커에 연결하여 실시간으로 알림을 주고받을 수 있습니다.
