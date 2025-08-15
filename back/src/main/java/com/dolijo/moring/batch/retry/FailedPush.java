package com.dolijo.moring.batch.retry;// package com.dolijo.moring.notification.retry;

import lombok.*;
import java.time.Instant;


/**
 * 푸시 알림 실패 처리를 나타내는 객체.
 * 실패한 푸시 알림의 정보를 저장하며, 재시도 로직에서 활용.
 */
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FailedPush {
    private String fcmToken;
    private String title;       // 잡별 타이틀(예: "차량 부품 소모율 알림")
    private String body;        // 메시지 본문
    private String jobName;     // 어떤 배치에서 나왔는지 구분(예: PartUsageAlertJob)
    private String detailType;  // 알림 상세 유형(예: PART_ALERT)
    private int attempt;        // 현재까지 시도 횟수
    private String lastError;   // 마지막 에러 메시지
    private Instant createdAt;  // 최초 적재 시각
    private Instant lastTriedAt;// 마지막 시도 시각
}