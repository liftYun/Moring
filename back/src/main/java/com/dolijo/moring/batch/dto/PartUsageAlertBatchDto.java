package com.dolijo.moring.batch.dto;

import lombok.Data;
import java.time.LocalDateTime;

@Data
public class PartUsageAlertBatchDto {
    private Long carId;
    private String carNickname;
    private String memberUuid;
    //private String memberName;
    private String partNameEn;
    private LocalDateTime lastChange;
    private Integer cycleMonths;
    private String fcmTokenId;
    private Integer percentUsed;
}

