package com.dolijo.moring.notifycation.vo.out;

import com.dolijo.moring.car.dto.CarInspectionLogResponseDto;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

import com.dolijo.moring.car.vo.out.CarInspectionLogResponseVo;
@Getter
@Builder
public final class NotificationResponseVo {
    private final Long id;
    private final String memberUuid;
    private final String notificationType;
    private final String message;
    private final Boolean readFlag;
    private final LocalDateTime createdAt;
}
