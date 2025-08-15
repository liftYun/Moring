package com.dolijo.moring.notifycation.service;

import com.dolijo.moring.car.entity.Car;
import com.dolijo.moring.car.repository.CarRepository;
import com.dolijo.moring.common.base.BaseResponseStatus;
import com.dolijo.moring.common.exception.BaseException;
import com.dolijo.moring.notifycation.dto.in.UnauthorizedUserRequestDto;
import com.dolijo.moring.notifycation.dto.out.UnauthorizedUserResponseDto;
import com.dolijo.moring.notifycation.valueobject.NotificationDetailType;
import com.dolijo.moring.notifycation.entity.Notification;
import com.dolijo.moring.notifycation.repository.NotificationRepository;
import com.dolijo.moring.notifycation.valueobject.NotificationType;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.time.LocalDateTime;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
@Log4j2
@RequiredArgsConstructor
public class SseService {

    // 차량별 SSE 연결 관리 (차량 VIN을 키로 사용)
    private final Map<String, SseEmitter> carConnections = new ConcurrentHashMap<>();

    private final CarRepository carRepository;
    private final NotificationRepository notificationRepository;
    private static final String UNAUTHORIZED_USER_DETECTED_SSE_EVENT_NAME = "UNAUTHORIZED_USER_DETECTED"; // SSE 이벤트 이름

    private static final long SSE_TIMEOUT = 30 * 60 * 1000L; // 30분

    /**
     * 차량 SSE 연결 생성
     * @param vin 차량 VIN
     * @return SseEmitter
     */
    public SseEmitter createCarConnection(String vin) {
        SseEmitter emitter = new SseEmitter(SSE_TIMEOUT);

        // 기존 연결이 있다면 종료
        SseEmitter existingEmitter = carConnections.get(vin);
        if (existingEmitter != null) {
            existingEmitter.complete();
        }

        carConnections.put(vin, emitter);

        // 연결 완료 시 정리
        emitter.onCompletion(() -> {
            carConnections.remove(vin);
            log.info("차량 SSE 연결 완료: {}", vin);
        });

        // 타임아웃 시 정리
        emitter.onTimeout(() -> {
            carConnections.remove(vin);
            log.info("차량 SSE 연결 타임아웃: {}", vin);
        });

        // 에러 시 정리
        emitter.onError((e) -> {
            carConnections.remove(vin);
            log.error("차량 SSE 연결 에러: {}", vin, e);
        });

        // 초기 연결 확인 메시지 전송
        try {
            emitter.send(SseEmitter.event()
                    .name("connect")
                    .data("차량 SSE 연결이 성공적으로 설정되었습니다."));
        } catch (IOException e) {
            log.error("초기 SSE 메시지 전송 실패: {}", vin, e);
            carConnections.remove(vin);
            emitter.completeWithError(e);
        }

        log.info("차량 SSE 연결 생성: {}", vin);
        return emitter;
    }

    /**
     * 차량에게 일반 알림 전송 (운행 중 발생하는 알림)
     * @param vin 차량 VIN
     * @param notificationDetailType 일반 알림 유형
     */
    @Transactional
    public void sendGeneralNotification(String vin, NotificationDetailType notificationDetailType) {
        // 1. 차량 조회
        Car car = carRepository.findByVin(vin)
                .orElseThrow(() -> new BaseException(BaseResponseStatus.NO_EXIST_CAR));

        // 2. SSE 연결 확인 및 알림 전송
        SseEmitter emitter = carConnections.get(vin);
        if (emitter != null) {
            try {
                // SSE를 통해 실시간 알림 전송
                emitter.send(SseEmitter.event()
                        .name(notificationDetailType.name())
                        .data(notificationDetailType.getDescription()));
                log.info("차량에게 일반 알림 전송 성공: {}, 알림유형: {}", vin, notificationDetailType.name());
                // 3. SSE 전송 성공 시에만 알림 엔티티 저장
                saveNotification(car, NotificationType.GENERAL, notificationDetailType);

            } catch (IOException e) {
                log.error("차량에게 일반 알림 전송 실패: {}, 알림유형: {}", vin, notificationDetailType.name(), e);
                // 전송 실패 시 연결 정리
                carConnections.remove(vin);
                emitter.completeWithError(e);
            }
        } else {
            log.warn("차량 SSE 연결이 존재하지 않음: {}", vin);
            throw new BaseException(BaseResponseStatus.NO_EXIST_SSE_CONNECTION);
        }
    }

    /**
     * 비등록 운전자 인식 알림 전송 (SSE 모달 트리거)
     */
    @Transactional(readOnly = true)
    public void sendUnauthorizedUserDetected(UnauthorizedUserRequestDto request) {
        String vin = request.getVin();

        Car car = carRepository.findByVin(vin)
                .orElseThrow(() -> new BaseException(BaseResponseStatus.NO_EXIST_CAR));

        SseEmitter emitter = carConnections.get(vin);
        if (emitter == null) {
            log.warn("차량 SSE 연결이 존재하지 않음: {}", vin);
            throw new BaseException(BaseResponseStatus.NO_EXIST_SSE_CONNECTION);
        }
        // 비등록 운전자 인식 알림 엔티티
        UnauthorizedUserResponseDto payload = UnauthorizedUserResponseDto.builder()
                .nickname(car.getNickname())
                .detectedAt(LocalDateTime.now())
                .unauthorizedUserImgUrl(request.getUnauthorizedUserImgUrl())
                .build();

        try {
            emitter.send(
                    SseEmitter.event()
                            .name(UNAUTHORIZED_USER_DETECTED_SSE_EVENT_NAME)  // 이벤트명 유지
                            .data(payload, MediaType.APPLICATION_JSON)        // 객체(JSON) 전송
            );
            log.info("비등록 운전자 인식 SSE 알림 전송 성공: vin={}, nickname={}, img={}",
                    vin, car.getNickname(), request.getUnauthorizedUserImgUrl());
        } catch (IOException e) {
            log.error("비등록 운전자 인식 SSE 알림 전송 실패: vin={}, nickname={}", vin, car.getNickname(), e);
            carConnections.remove(vin);
            emitter.completeWithError(e);
            throw new BaseException(BaseResponseStatus.NO_EXIST_SSE_CONNECTION);
        }
    }

    /**
     * 알림 엔티티 저장
     * @param car 차량 엔티티
     * @param notificationType 알림 유형
     * @param notificationDetailType 일반 알림 유형
     */
    private void saveNotification(Car car, NotificationType notificationType, NotificationDetailType notificationDetailType) {
        Notification notification = Notification.builder()
                .car(car)
                .notificationType(notificationType)
                .notificationDetail(notificationDetailType)
                .message(notificationDetailType.getDescription())
                .readFlag(false)
                .build();

        notificationRepository.save(notification);
        log.info("알림 저장 완료 - 차량: {}, 유형: {}, 내용: {}",
                car.getVin(), notificationType, notificationDetailType.getDescription());
    }



    /**
     * 차량 연결 해제
     * @param vin 차량 VIN
     */
    public void disconnectCar(String vin) {
        SseEmitter emitter = carConnections.remove(vin);
        if (emitter != null) {
            emitter.complete();
            log.info("차량 SSE 연결 해제: {}", vin);
        }
    }

    /**
     * 현재 연결된 차량 수 조회
     * @return 연결된 차량 수
     */
    public int getCarConnectionCount() {
        return carConnections.size();
    }

    /**
     * 특정 차량의 연결 상태 확인
     * @param vin 차량 VIN
     * @return 연결 여부
     */
    public boolean isCarConnected(String vin) {
        return carConnections.containsKey(vin);
    }
}
