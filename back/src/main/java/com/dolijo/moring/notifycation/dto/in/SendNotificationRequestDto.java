package com.dolijo.moring.notifycation.dto.in;

import com.dolijo.moring.member.valueobject.GeneralNotificationType;
import com.dolijo.moring.notifycation.valueobject.NotificationType;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public final class SendNotificationRequestDto {
    private final String memberUuid;
    private final String carVin;
    private final NotificationType notificationType;
    private final GeneralNotificationType generalNotificationType;
    private final String message;
    private final String eventName;
}
