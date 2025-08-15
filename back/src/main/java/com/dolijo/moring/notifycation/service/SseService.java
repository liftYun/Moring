package com.dolijo.moring.notifycation.service;

import com.dolijo.moring.car.entity.Car;
import com.dolijo.moring.car.repository.CarRepository;
import com.dolijo.moring.common.base.BaseResponseStatus;
import com.dolijo.moring.common.exception.BaseException;
import com.dolijo.moring.notifycation.valueobject.NotificationDetailType;
import com.dolijo.moring.notifycation.entity.Notification;
import com.dolijo.moring.notifycation.repository.NotificationRepository;
import com.dolijo.moring.notifycation.valueobject.NotificationType;
import jakarta.annotation.PreDestroy;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.util.Map;
import java.util.concurrent.*;

@Service
@Log4j2
@RequiredArgsConstructor
public class SseService {

    // 차량별 SSE 연결 관리 (차량 VIN을 키로 사용)
    private final Map<String, Entry> carConnections = new ConcurrentHashMap<>();

    private final CarRepository carRepository;
    private final NotificationRepository notificationRepository;
    private static final String UNAUTHORIZED_USER_DETECTED_SSE_EVENT_NAME = "UNAUTHORIZED_USER_DETECTED"; // SSE 이벤트 이름

    private static final long SSE_TIMEOUT = 30 * 60 * 1000L; // 30분
    private static final long HEARTBEAT_SEC = 15;

    private static class Entry {
        final SseEmitter emitter;
        final ScheduledFuture<?> heartbeat;
        Entry(SseEmitter e, ScheduledFuture<?> h) { this.emitter = e; this.heartbeat = h; }
    }

    private final ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(2);


    /**
     * 차량 SSE 연결 생성
     * @param carVin 차량 VIN
     * @return SseEmitter
     */
    public SseEmitter createCarConnection(String carVin) {
        // 기존 연결이 있다면 종료
        disconnectCar(carVin);
        SseEmitter emitter = new SseEmitter(SSE_TIMEOUT);

        // 연결 완료 시 정리
        emitter.onCompletion(() -> {
            carConnections.remove(carVin);
            log.info("차량 SSE 연결 완료: {}", carVin);
        });

        // 타임아웃 시 정리
        emitter.onTimeout(() -> {
            carConnections.remove(carVin);
            log.info("차량 SSE 연결 타임아웃: {}", carVin);
        });

        // 에러 시 정리
        emitter.onError((e) -> {
            carConnections.remove(carVin);
            log.error("차량 SSE 연결 에러: {}", carVin, e);
        });

        // 초기 연결 확인 메시지 전송
        try {
            emitter.send(SseEmitter.event()
                    .name("connect")
                    .data("차량 SSE 연결이 성공적으로 설정되었습니다."));
        } catch (IOException e) {
            log.error("초기 SSE 메시지 전송 실패: {}", carVin, e);
            // 재연결 전송을 위해 일단 주석해둘게용
//            carConnections.remove(carVin);
            emitter.completeWithError(e);
            return emitter;
        }

//        log.info("차량 SSE 연결 생성: {}", carVin);
//        return emitter;
        // 하트비트: 15초마다 ping 이벤트 (또는 주석 프레임)
        ScheduledFuture<?> hb = scheduler.scheduleAtFixedRate(() -> {
            Entry entry = carConnections.get(carVin);
            if (entry == null) return;
            try {
                entry.emitter.send(SseEmitter.event().name("ping").data("💓"));
                // 또는 주석 프레임을 원하면:
                // entry.emitter.send(":\n\n");
            } catch (IOException ex) {
                log.warn("[SSE] heartbeat send fail vin={} - {}", carVin, ex.toString());
                entry.emitter.completeWithError(ex);
                cleanup(carVin, "heartbeat-fail");
            }
        }, HEARTBEAT_SEC, HEARTBEAT_SEC, TimeUnit.SECONDS);

        carConnections.put(carVin, new Entry(emitter, hb));
        log.info("차량 SSE 연결 생성: {}", carVin);
        return emitter;
    }

    /**
     * 차량에게 일반 알림 전송 (운행 중 발생하는 알림)
     * @param carVin 차량 VIN
     * @param notificationDetailType 일반 알림 유형
     */
    @Transactional
    public void sendGeneralNotification(String carVin, NotificationDetailType notificationDetailType) {
        // 1. 차량 조회
        Car car = carRepository.findByVin(carVin)
                .orElseThrow(() -> new BaseException(BaseResponseStatus.NO_EXIST_CAR));

        // 2. SSE 연결 확인 및 알림 전송
        Entry entry = carConnections.get(carVin);
        if (entry != null) {
            try {
                // SSE를 통해 실시간 알림 전송
                entry.emitter.send(SseEmitter.event()
                        .name(notificationDetailType.name())
                        .data(notificationDetailType.getDescription()));
                log.info("차량에게 일반 알림 전송 성공: {}, 알림유형: {}", carVin, notificationDetailType.name());
                // 3. SSE 전송 성공 시에만 알림 엔티티 저장
                saveNotification(car, NotificationType.GENERAL, notificationDetailType);

            } catch (IOException e) {
                log.error("차량에게 일반 알림 전송 실패: {}, 알림유형: {}", carVin, notificationDetailType.name(), e);
                // 전송 실패 시 연결 정리
                carConnections.remove(carVin);
                entry.emitter.completeWithError(e);
            }
        } else {
            log.warn("차량 SSE 연결이 존재하지 않음: {}", carVin);
            throw new BaseException(BaseResponseStatus.NO_EXIST_SSE_CONNECTION);
        }
    }

    /**
     * 비등록 운전자 인식 알림 전송 (SSE 모달 트리거)
     * @param carVin 차량 VIN
     */
    @Transactional
    public void sendUnauthorizedUserDetected(String carVin) {
        Car car = carRepository.findByVin(carVin)
                .orElseThrow(() -> new BaseException(BaseResponseStatus.NO_EXIST_CAR));

        Entry entry = carConnections.get(carVin);
        if (entry != null) {
            try {
                entry.emitter.send(SseEmitter.event()
                        .name(UNAUTHORIZED_USER_DETECTED_SSE_EVENT_NAME)
                        .data(UNAUTHORIZED_USER_DETECTED_SSE_EVENT_NAME)); // 데이터에도 동일 문자열 전송
                log.info("비등록 운전자 인식 SSE 알림 전송 성공: {}", carVin);
            } catch (IOException e) {
                log.error("비등록 운전자 인식 SSE 알림 전송 실패: {}", carVin, e);
                carConnections.remove(carVin);
                entry.emitter.completeWithError(e);
            }
        } else {
            log.warn("차량 SSE 연결이 존재하지 않음: {}", carVin);
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
     * @param carVin 차량 VIN
     */
    public void disconnectCar(String carVin) {
        Entry entry = carConnections.remove(carVin);
        if (entry != null) {
            entry.emitter.complete();
            log.info("차량 SSE 연결 해제: {}", carVin);
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
     * @param carVin 차량 VIN
     * @return 연결 여부
     */
    public boolean isCarConnected(String carVin) {
        return carConnections.containsKey(carVin);
    }

    private void cleanup(String carVin, String reason) {
        Entry entry = carConnections.remove(carVin);
        if (entry != null) {
            if (entry.heartbeat != null) entry.heartbeat.cancel(true);
            try { entry.emitter.complete(); } catch (Exception ignored) {}
            log.info("차량 SSE 연결 정리 vin={}, reason={}", carVin, reason);
        }
    }

    @PreDestroy
    public void shutdown() {
        carConnections.keySet().forEach(v -> cleanup(v, "shutdown"));
        scheduler.shutdownNow();
    }
}
