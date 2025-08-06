package com.dolijo.moring.batch.dto;

import com.dolijo.moring.notifycation.valueobject.NotificationDetailType;
import com.dolijo.moring.notifycation.valueobject.NotificationType;
import lombok.Data;

/**
 * 알림 테이블 저장용 배치 DTO
 */
@Data
public class NotificationBatchDto {
    private Long carId; // 차량 ID
    private String notificationType; // 알림 유형 (enum)
    private String notificationDetailType; // 알림 상세 유형 (enum)
    private String message; // 알림 메시지
}
