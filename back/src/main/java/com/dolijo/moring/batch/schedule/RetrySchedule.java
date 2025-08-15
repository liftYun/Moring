package com.dolijo.moring.batch.schedule;

import com.dolijo.moring.batch.retry.FailedPush;
import com.dolijo.moring.batch.retry.PushRetryRepository;
import com.dolijo.moring.notifycation.service.PushService;
import com.dolijo.moring.batch.dto.FCMNotificationRequestDto;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Instant;

/**
 * Redis 리스트(push-retry:queue)에 저장된 실패 푸시 알림을
 * 30분마다 꺼내 재시도 처리한다.
 * - 각 항목은 최대 3회까지 재시도
 * - 실패 시 attempt+1 하고 다시 큐에 재적재
 * - 성공 시 삭제(재적재 안 함)
 */
@Log4j2
@Component
@RequiredArgsConstructor
public class RetrySchedule {

    private static final int MAX_ATTEMPTS = 3;           // 최대 재시도 횟수
    private static final int MAX_PROCESS_PER_RUN = 1000; // 한 번 실행 시 최대 처리 건수 (안전 장치)

    private final PushRetryRepository retryRepository; // Redis 리스트 래퍼
    private final PushService pushService;      // 스케줄러에서는 PushSender 대신 직접 호출
    private final ObjectMapper objectMapper;

    //30분마다 실행 (테스트 시 */1, 운영 시 */30)
    @Scheduled(cron = "0 */30 * * * *")
    public void retryFailedPushes() {
        // 큐 길이 확인
        Long queueSize = retryRepository.size(); // LLEN 래핑 메서드
        if (queueSize == null || queueSize == 0) {
            log.info("[푸시 재시도] 큐가 비어있어 실행을 건너뜁니다.");
            return;
        }

        log.info("[푸시 재시도] 스케줄러 시작 | 현재 큐 길이: {}건", queueSize);
        int processed = 0, reEnqueued = 0, skipped = 0, succeeded = 0;

        // 각 푸시 실패 건을 3번 까지 재시도
        while (processed < MAX_PROCESS_PER_RUN) {
            String json = retryRepository.popOne();
            if (json == null) break;
            processed++;

            FailedPush item;
            try {
                item = objectMapper.readValue(json, FailedPush.class);
            } catch (Exception e) {
                log.error("[푸시 재시도] 잘못된 JSON 데이터, 폐기: {}", json, e);
                continue;
            }

            if (item.getAttempt() >= MAX_ATTEMPTS) {
                skipped++;
                log.warn("[푸시 재시도] 최대 재시도 횟수 초과로 폐기");
                continue;
            }
            try {
                // 재전송
                pushService.sendPushNotification(
                        FCMNotificationRequestDto.builder()
                                .fcmToken(item.getFcmToken())
                                .title(item.getTitle())
                                .body(item.getBody())
                                .build()
                );
                succeeded++;
                log.info("[푸시 재시도] 전송 성공: 토큰={}, 제목={}", item.getFcmToken(), item.getTitle());
            } catch (Exception ex) {
                item.setAttempt(item.getAttempt() + 1);
                item.setLastError(ex.toString());
                item.setLastTriedAt(Instant.now());
                retryRepository.enqueue(item); // 재적재
                reEnqueued++;
                log.warn("[푸시 재시도] 전송 실패 → 재적재됨 (시도횟수={}): 토큰={}, 제목={}, 에러={}",
                        item.getAttempt(), item.getFcmToken(), item.getTitle(), ex.toString());
            }
        }
        log.info("[푸시 재시도 결과] 스케줄러 종료 | 처리시도={}건, 성공={}건, 재적재={}건, 폐기(시도초과)={}건",
                processed, succeeded, reEnqueued, skipped);
    }
}