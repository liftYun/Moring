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
import jakarta.annotation.PreDestroy;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.Map;
import java.util.concurrent.*;

@Service
@Log4j2
@RequiredArgsConstructor
@Transactional
public class SseService {

    // 차량별 SSE 연결 관리 (차량 VIN을 키로 사용)
    private final Map<String, Entry> carConnections = new ConcurrentHashMap<>();
    private final CarRepository carRepository;
    private final NotificationRepository notificationRepository;
    private static final String UNAUTHORIZED_USER_DETECTED_SSE_EVENT_NAME = "UNAUTHORIZED_USER_DETECTED"; // SSE 이벤트 이름
    private static final long SSE_TIMEOUT = 30 * 60 * 1000L; // 30분
    private static final long HEARTBEAT_SEC = 15;

    private final StringRedisTemplate redis;
    @Value("${spring.data.redis.authorized-user-status-key-prefix}")
    private String authorizedUserStatusKeyPrefix; // 레디스 비인가 사용자 상태 키 접두사
    private final int REDIS_KEY_ALIVE_MINUTES = 3; // Redis 키 TTL (분 단위)
    private static class Entry {
        final SseEmitter emitter;
        final ScheduledFuture<?> heartbeat;
        Entry(SseEmitter e, ScheduledFuture<?> h) { this.emitter = e; this.heartbeat = h; }
    }

    private final ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(2);


    /**
     * 차량 SSE 연결 생성
     * @param vin 차량 VIN
     * @return SseEmitter
     */

    public SseEmitter createCarConnection(String vin) {
        // 기존 연결이 있다면 종료
        disconnectCar(vin);
        SseEmitter emitter = new SseEmitter(SSE_TIMEOUT);

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
            // 재연결 전송을 위해 일단 주석해둘게용
//            carConnections.remove(vin);
            emitter.completeWithError(e);
            return emitter;
        }

//        log.info("차량 SSE 연결 생성: {}", vin);
//        return emitter;
        // 하트비트: 15초마다 ping 이벤트 (또는 주석 프레임)
        ScheduledFuture<?> hb = scheduler.scheduleAtFixedRate(() -> {
            Entry entry = carConnections.get(vin);
            if (entry == null) return;
            try {
                entry.emitter.send(SseEmitter.event().name("ping").data("💓"));
                // 또는 주석 프레임을 원하면:
                // entry.emitter.send(":\n\n");
            } catch (IOException ex) {
                log.warn("[SSE] heartbeat send fail vin={} - {}", vin, ex.toString());
                entry.emitter.completeWithError(ex);
                cleanup(vin, "heartbeat-fail");
            }
        }, HEARTBEAT_SEC, HEARTBEAT_SEC, TimeUnit.SECONDS);

        carConnections.put(vin, new Entry(emitter, hb));
        log.info("차량 SSE 연결 생성: {}", vin);
        return emitter;
    }

    /**
     * 차량에게 일반 알림 전송 (운행 중 발생하는 알림)
     * @param vin 차량 VIN
     * @param notificationDetailType 일반 알림 유형
     */
    public void sendGeneralNotification(String vin, NotificationDetailType notificationDetailType) {
        // 1. 차량 조회
        Car car = carRepository.findByVin(vin)
                .orElseThrow(() -> new BaseException(BaseResponseStatus.NO_EXIST_CAR));

        // 2. SSE 연결 확인 및 알림 전송
        Entry entry = carConnections.get(vin);
        if (entry != null) {
            try {
                // SSE를 통해 실시간 알림 전송
                entry.emitter.send(SseEmitter.event()
                        .name(notificationDetailType.name())
                        .data(notificationDetailType.getDescription()));
                log.info("차량에게 일반 알림 전송 성공: {}, 알림유형: {}", vin, notificationDetailType.name());
                // 3. SSE 전송 성공 시에만 알림 엔티티 저장
                saveNotification(car, NotificationType.GENERAL, notificationDetailType);

            } catch (IOException e) {
                log.error("차량에게 일반 알림 전송 실패: {}, 알림유형: {}", vin, notificationDetailType.name(), e);
                // 전송 실패 시 연결 정리
                carConnections.remove(vin);
                entry.emitter.completeWithError(e);
            }
        } else {
            log.warn("차량 SSE 연결이 존재하지 않음: {}", vin);
            throw new BaseException(BaseResponseStatus.NO_EXIST_SSE_CONNECTION);
        }
    }

    public void sendUnauthorizedUserDetected(UnauthorizedUserRequestDto request) {
        String vin = request.getVin();

        Car car = carRepository.findByVin(vin)
                .orElseThrow(() -> new BaseException(BaseResponseStatus.NO_EXIST_CAR));

        Entry entry = carConnections.get(vin);
        if (entry == null) {
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
            entry.emitter.send(
                    SseEmitter.event()
                            .name(UNAUTHORIZED_USER_DETECTED_SSE_EVENT_NAME)  // 이벤트명 유지
                            .data(payload, MediaType.APPLICATION_JSON)        // 객체(JSON) 전송
            );
            log.info("비등록 운전자 인식 SSE 알림 전송 성공: vin={}, nickname={}, img={}",
                    vin, car.getNickname(), request.getUnauthorizedUserImgUrl());
        } catch (IOException e) {
            log.error("비등록 운전자 인식 SSE 알림 전송 실패: vin={}, nickname={}", vin, car.getNickname(), e);
            carConnections.remove(vin);
            entry.emitter.completeWithError(e);
            throw new BaseException(BaseResponseStatus.NO_EXIST_SSE_CONNECTION);
        }
        // 비등록 사용자 SSE 결과 관련 대기상태 저장
        try {
            String key = authorizedUserStatusKeyPrefix + vin;
            // 초기값은 진짜 null 대신 "null" 문자열로 저장 + TTL 지정된 시간
            redis.opsForValue().set(key, "pending", Duration.ofMinutes(REDIS_KEY_ALIVE_MINUTES));
            log.info("Redis에 키 설정: {}, 초기값: null, TTL: 1분", key);
        } catch (Exception e) {
            // 에러 로그에 vin 변수가 들어가야해 하드코딩됨
            log.error("Redis 키 설정 실패: {}:unauthorizedUser-status", vin, e);
            throw new BaseException(BaseResponseStatus.REDIS_ERROR);
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
        Entry entry = carConnections.remove(vin);
        if (entry != null) {
            entry.emitter.complete();
            log.info("차량 SSE 연결 해제: {}", vin);
        }
    }

    /**
     * 현재 연결된 차량 수 조회
     * @return 연결된 차량 수
     */
    @Transactional(readOnly = true)
    public int getCarConnectionCount() {
        return carConnections.size();
    }

    /**
     * 특정 차량의 연결 상태 확인
     * @param vin 차량 VIN
     * @return 연결 여부
     */
    @Transactional(readOnly = true)
    public boolean isCarConnected(String vin) {
        return carConnections.containsKey(vin);
    }

    private void cleanup(String vin, String reason) {
        Entry entry = carConnections.remove(vin);
        if (entry != null) {
            if (entry.heartbeat != null) entry.heartbeat.cancel(true);
            try { entry.emitter.complete(); } catch (Exception ignored) {}
            log.info("차량 SSE 연결 정리 vin={}, reason={}", vin, reason);
        }
    }

    @PreDestroy
    public void shutdown() {
        carConnections.keySet().forEach(v -> cleanup(v, "shutdown"));
        scheduler.shutdownNow();
    }
}
