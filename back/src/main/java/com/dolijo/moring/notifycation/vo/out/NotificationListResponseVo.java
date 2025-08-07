package com.dolijo.moring.notifycation.vo.out;

import com.dolijo.moring.notifycation.valueobject.NotificationDetailType;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NotificationListResponseVo {
    @Schema(description = "알림 ID")
    private Long id;
    @Schema(description = "알림 상세 유형")
    private NotificationDetailType notificationDetail;
    @Schema(description = "알림 생성일시")
    private LocalDateTime createdAt;
    @Schema(description = "알림 메시지")
    private String message;
}

