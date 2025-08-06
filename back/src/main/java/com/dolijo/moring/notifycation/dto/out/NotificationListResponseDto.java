package com.dolijo.moring.notifycation.dto.out;

import com.dolijo.moring.notifycation.valueobject.NotificationDetailType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NotificationListResponseDto {
    private Long id;
    private NotificationDetailType notificationDetail;
    private LocalDateTime createdAt;
    private String message;
}

