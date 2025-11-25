# 🚘MORING

![Cover.jpg](attachment:1fe8c86c-a04f-424e-b6bc-4aeead278f3f:Cover.jpg)

![MORING - HW
(잿슨오린나노(developerkit) driver verision540.4.0 )
 라즈베리파이5
 카메라(BRIO-100)
 온습도센서(DHT11)
 이산화탄소센서(MH-Z19B)
 부저(active 피애조 부저)
 ](attachment:82c87d33-73a0-41aa-bb82-46ca229a0bb9:image.png)

MORING - HW
(잿슨오린나노(developerkit) driver verision540.4.0 )
 라즈베리파이5
 카메라(BRIO-100)
 온습도센서(DHT11)
 이산화탄소센서(MH-Z19B)
 부저(active 피애조 부저)
 

![MORING - MOBILE APP](attachment:916b560d-3b0c-46bd-8646-8cd260cac05d:image.png)

MORING - MOBILE APP

## 🦺 [ 스마트 드라이빙 케어 ] 서비스 MORING

개발 기간 : 2025.07.xx ~ 2025.08.

개발 인원 : 6명

---

1. 실시간 시선 추적 및 졸음 감지로 운전 중 위험 상황 시 즉시 알림 제공
2. 차량 점검일 및 주요 부품 교환 주기에 따른 푸시 알림 제공
3. 운전 중 STT/TTS 기반 AI 음성 상호작용으로 운전·안전·교통 정보 안내
4. 운행 이력(드라이빙 로그) 실시간 저장 및 조회 기능 제공
5. 등록되지 않은 운전자 식별 시 차주·관리자에게 즉시 알림 연계

## 목차

## 👨‍🔧 기술 스택

---

- **HARDWARE**
    - **PAHO - MQTT  2.1.0**
    - **Jetson Nano**
        - OS: Ubuntu 22.04.5 LTS
        - Python 3.10.12
        - NVIDIA_jetpack 6.2
        - cmake : 4.1.0
        - dlib : 20.0.0
        - face-recognition : 1.3.0
        - opencv: 4.11.0.86
        - tensorrt: 10.3.0
        - torch: 2.8.0
        - pillow 11.3.0
        - CUDA: 12.6
    - **Raspberry Pi**
        - OS: Debian GNU/Linux 12
        - Python 3.10.12
- **BAKCEND**
    - **Spring boot 3.5.4**
    - **Spring batch 5.2.2**
    - **Java 17**
    - **Cool sms -  net.nurigo 4.3.0**
    - **Firebase Admin SDK: 9.5.0**
    - **JWT (jjwt): 0.12.3 (api, impl, jackson)**
    - **Spring Data Jpa 3.5.2**
    - **Spring data-redis 3.5.2**
    - **QueryDSL: 5.0.0 (jakarta)**
    - **Swagger / OpenAPI: 2.7.0 (springdoc-openapi-starter-webmvc-ui)**
- **FRONTEND**
    - **CLOVA Speech Recognition(CSR)**
    - **Flutter 3.32.7**
    - **Dart 3.8.1**
    - **kakao_fultter_sdk : 1.9.5**
    - **firebase**
        - **firebase_core : 4.0.0**
        - **firebase_messaging : 16.0.0**
    - **google_maps_flutter : 2.8.0**
- DevOps
    - OS : Ubuntu 22.04.4 LTS
    - Jenkins : 2.516.1
    - nginx : 1.27
    - certbot : 4.2.0
    - Mysql : 8.4.6

## 📎 시스템 아키텍처

---

## 📶 API 정의

---

- 차량
    
    
    | HTTP 메서드 | 경로 | 반환값 |
    | --- | --- | --- |
    | POST | /api/v1/cars/ | **{ 
    "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": 0
    }** |
    | GET | /api/v1/cars/{memberUuid}/list | **{ 
    "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": [ { "vin": "string", "modelName": "string", "nickname": "string" } ]
    }** |
    | DELETE | /api/v1/cars/{vin} | **{ 
    "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": {}
    }** |
    | POST | /api/v1/cars/{vin}/inspection | **{ 
    "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": {}
    }** |
    | GET | /api/v1/cars/{vin}/inspection-logs-paging | **{ 
    "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": { "size": 0, "content": [ { "inspectionDateTime": "2025-08-21T05:39:07.541Z", "inspectionStatus": "string" } ], "number": 0, "sort": { "empty": true, "sorted": true, "unsorted": true }, "first": true, "last": true, "numberOfElements": 0, "pageable": { "offset": 0, "sort": { "empty": true, "sorted": true, "unsorted": true }, "paged": true, "pageNumber": 0, "pageSize": 0, "unpaged": true }, "empty": true }
    }** |
    | GET | /api/v1/cars/{vin}/latest-pending-inspection-date | **{
     "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": "2025-08-21"
    }** |
    | GET | /api/v1/cars/{vin}/mileage-logs-paging | **{ 
    "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": { "size": 0, "content": [ { "mileageKm": 0, "recordedDate": "2025-08-21" } ], "number": 0, "sort": { "empty": true, "sorted": true, "unsorted": true }, "first": true, "last": true, "numberOfElements": 0, "pageable": { "offset": 0, "sort": { "empty": true, "sorted": true, "unsorted": true }, "paged": true, "pageNumber": 0, "pageSize": 0, "unpaged": true }, "empty": true }
    }** |
    | POST | /api/v1/cars/{vin}/{km} | **{ 
    "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": {}
    }** |
    
- 배치
    
    
    | HTTP 메서드 | 경로 | 반환값 |
    | --- | --- | --- |
    | GET | /api/v1/batch/car-inspection-alert | **string** |
    | GET | /api/v1/batch/part-usage-alert | **string** |
    
- 알림
    
    
    | HTTP 메서드 | 경로 | 반환값 |
    | --- | --- | --- |
    | GET | /api/v1/notifications/connect/{carVin} | **{ 
    "timeout": 0
    }** |
    | DELETE | /api/v1/notifications/disconnect/{carVin} | **{ 
    "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": {}
    }** |
    | GET | /api/v1/notifications/status | **{ 
    "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": { "carConnectionCount": 0, "status": "string", "message": "string" }
    }** |
    | GET | /api/v1/notifications/status/{carVin} | **{ 
    "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": true
    }** |
    | GET | /api/v1/notifications/{vin}/count | **{ 
    "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": 0
    }** |
    | PATCH | /api/v1/notifications/{vin}/read-all | **{ 
    "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": 0
    }** |
    | GET | /api/v1/notifications/{vin}/unread | **{ 
    "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": { "size": 0, "content": [ { "id": 0, "notificationDetail": "FRONT_ALERT", "createdAt": "2025-08-21T05:45:24.622Z", "message": "string" } ], "number": 0, "sort": { "empty": true, "sorted": true, "unsorted": true }, "first": true, "last": true, "numberOfElements": 0, "pageable": { "offset": 0, "sort": { "empty": true, "sorted": true, "unsorted": true }, "paged": true, "pageNumber": 0, "pageSize": 0, "unpaged": true }, "empty": true }
    }** |
    | PATCH | /api/v1/notifications/read/{notificationId} | **{ 
    "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": {}
    }** |
    | POST | /api/v1/notifications/send/general/{carVin} | **{
     "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": {}
    }** |
- AI
    
    
    | HTTP 메서드 | 경로 | 반환값 |
    | --- | --- | --- |
    | POST | /api/v1/AI/ask | {
    "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, 	"isSuccess": true, "message": "string", "code": 0, "result": "string"
    } |
    | POST | /api/v1/AI/car-registration | **{ 
    "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": { "vin": "string", "modelName": "string", "registeredAt": "2025-08-21" }
    }** |
    | POST | /api/v1/AI/part-repair-estimate-ocr | **{ 
    "changedAt": "2025-08-21T05:36:35.399Z", "partIdList": [ 0 ]
    }** |
    | GET | /api/v1/AI/test | **{ 
    "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": {}
    }** |
- 부품
    
    
    | HTTP 메서드 | 경로 | 반환값 |
    | --- | --- | --- |
    | GET | /api/v1/parts/ | **{ 
    "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": [ { "id": 1, "nameKo": "엔진오일", "nameEn": "Engine Oil", "recommendedCycleMonths": 6, "recommendedCycleKm": 10000, "type": "CONSUMABLE", "description": "엔진 보호를 위해 주기적으로 교환해야 하는 오일입니다." } ]
    }** |
    | POST | /api/v1/parts/ | **{ 
    "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": 0
    }** |
    | POST | /api/v1/parts/change-log | **{
     "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": [ 0 ]
    }** |
    | GET | /api/v1/parts/status/{vin} | **{ 
    "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": [ { "partId": 0, "nameKo": "string", "percentUsed": 0, "dueDate": "2025-08-21" } ]
    }** |
- SMS
    
    
    | HTTP 메서드 | 경로 | 반환값 |
    | --- | --- | --- |
    | POST | /api/v1/sms/send/info | string |
- 회원
    
    
    | HTTP 메서드 | 경로 | 반환값 |
    | --- | --- | --- |
    | GET | /api/v1/auth/login/test | 200 OK (no body) |
    | POST | /api/v1/auth/logout/rToken | **{ 
    "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": {}
    }** |
    | POST | /api/v1/auth/refresh | **{ "accessToken": "string", "refreshToken": "string"
    }** |
    | GET | /api/v1/members/mypage | **{ 
    "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": { "uuid": "string", "email": "string", "nickName": "string" }
    }** |
    | PATCH | /api/v1/members/fcm | **{
     "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": {}
    }** |
    | PATCH | /api/v1/members/update/{nickName} | **{ 
    "httpStatus": { "error": true, "is2xxSuccessful": true, "is5xxServerError": true, "is4xxClientError": true, "is3xxRedirection": true, "is1xxInformational": true }, "isSuccess": true, "message": "string", "code": 0, "result": {}
    }** |

## 📰 ERD

---

![image.png](attachment:28365c29-7a09-49ef-8905-25fcdfa0c171:image.png)

## 📺 주요 기능 둘러보기

---

# 🚘 MORING — 주요 기능 정리

---

## 🔐 로그인 & 온보딩 🔔 알림센터

![로그인](attachment:dca4ed63-11e1-4f70-ad81-1bf939c9b9f3:로그인.mp4.gif)

![받은알림-확인.mp4.gif](attachment:5b35939f-19b4-435f-8241-770c604b3f3e:받은알림-확인.mp4.gif)

- **카카오 로그인 / 테스트 로그인**으로 빠른 진입
- 첫 실행 시 권한/알림 안내까지 one-step 온보딩
- 종 아이콘 배지로 미확인 개수 표시, **개별/전체 읽음 처리**

---

## 🚗 차량 등록 & 연결

![차량 등록 수동](attachment:0f5c7301-e02e-4aef-8ac4-fbdeff4ccfff:차량등록수동.gif)

![차량등록 OCR (1).mp4.gif](attachment:37561922-9d29-43f1-b9e3-8c0a2a66942d:차량등록_OCR_(1).mp4.gif)

- 차대번호, 애칭, 모델명, 등록일을 직접 입력해 **수동 등록**
- 차량 등록증 스캔으로 **OCR 자동 등록**도 지원
- 등록증 촬영만으로 주요 정보 자동 인식
- 사용자 편의성을 높인 **원클릭 등록 플로우**
- 차량이 연결되지 않은 경우, 앱에서 즉시 알림을 띄워
“차량 등록하러 가기”로 유도

---

## 👤 미등록 운전자 감지 & 처리

![미등록 운전자 감지 - 예](attachment:a48ea5d6-6a20-4d04-84ef-df61d960e667:미등록사용자_예_.mp4.gif)

![미등록사용자등록_아니요_.mp4.gif](attachment:340cd12b-b10b-4862-b157-95d48f86a782:미등록사용자등록_아니요_.mp4.gif)

- 카메라·얼굴 임베딩으로 **미등록 운전자 감지 시 즉시 경고**
- 차주/관리자에게 푸시 연계
- 앱에서 **등록/미등록** 간편 처리 → 화이트리스트 즉시 반영

---

## 🗣️ 내비게이션,음성 비서 (STT/TTS)(SSE 실시간)

![네비 경로 안내](attachment:f1d777ea-0a33-459c-816e-e254dbefda0c:네비경로안내.gif)

![AI 음성 대화](attachment:1b288648-9c90-48fd-94a8-9592962ba3d3:ai음성대화.webm.mp4.gif)

![받은알림 확인](attachment:9f91a652-51ab-4ad2-b135-6839ebbf0c39:일반-알림전송2.mp4.gif)

- **음성으로 목적지·안전·정비 일정 질의/응답**
- 클로바 CSR + LLM 연동, 주행 중 **핸즈프리 대화형 인터페이스**
- 서버-센트 이벤트(SSE) 기반 **실시간 알림 수신**
- 음성/검색 입력 → **경로 계산 및 안내**
- 확대/축소, 현재 위치 복귀 등 드라이빙 최적화 조작

---

## 🧾 부품 교체 견적 & 등록 (OCR/수동)

![부품 OCR](attachment:70038460-48d0-4ad7-843a-e74a7d6bfe03:부품등록_단일_.mp4.gif)

![부품등록_다중_.mp4.gif](attachment:21ca89d3-8ae1-42f3-89ca-afb218fde1f5:부품등록_다중_.mp4.gif)

![부품OCR.mp4.gif](attachment:201e4e7e-328d-491f-b624-2aa50ff550db:부품OCR.mp4.gif)

- 정비 영수증/견적서 **OCR 자동 인식**
- 인식 부품을 **잔여율·권장 교환주기**와 연동하여 교체 일정 반영
- 특정 부품 하나만 선택하여 **개별 등록**
- 여러 소모품을 동시에 선택하여 **일괄 등록**
- 각 부품별 **잔여율과 교체 주기**를 직관적인 게이지로 표시
- 사용자 직접 **내역 수정/보정** 가능

---
