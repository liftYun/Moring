package com.dolijo.moring.batch.retry;// package com.dolijo.moring.notification;


import com.dolijo.moring.notifycation.service.PushService; // 기존 푸시 서비스
import com.dolijo.moring.batch.dto.FCMNotificationRequestDto;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.concurrent.CompletableFuture;

@Log4j2
@Service
@RequiredArgsConstructor
public class PushSender {

    private final PushService pushService; // 실제 FCM 호출하는 기존 서비스
    private final PushRetryRepository retryRepo;

    @Async("pushAsyncExecutor")
    public CompletableFuture<Void> sendAsync(String fcmToken, String title, String body, String jobName,
                                             String detailType) {
        try {

//            log.info("강제에러 발생");
//            throw new RuntimeException("강제 테스트 예외: 푸시 전송 실패 시뮬레이션");

            pushService.sendPushNotification(
                    FCMNotificationRequestDto.builder()
                            .fcmToken(fcmToken)
                            .title(title)
                            .body(body)
                            .build()
            );
            return CompletableFuture.completedFuture(null);
        } catch (Exception ex) {
            retryRepo.enqueue(FailedPush.builder()
                    .fcmToken(fcmToken)
                    .title(title)
                    .body(body)
                    .jobName(jobName)
                    .detailType(detailType)
                    .attempt(0)
                    .lastError(ex.toString())
                    .createdAt(Instant.now())
                    .build());
            log.info("강제에러 저장 완료");
            return CompletableFuture.failedFuture(ex);
        }
    }


}