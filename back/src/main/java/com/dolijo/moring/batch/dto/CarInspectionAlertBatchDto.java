package com.dolijo.moring.batch.dto;

import lombok.Data;
import java.time.LocalDate;

/**
 * 정기점검 알림 배치용 DTO
 * - 차량, 회원, 점검 로그 정보 포함
 */
@Data
public class CarInspectionAlertBatchDto {
    private Long carId;           // 차량 ID
    private String carNickname;       // 차량 별명
    private String memberUuid;    // 회원 UUID
    private String memberName;    // 회원 이름
    private LocalDate inspectionDate; // 정기점검 마감일
    private int daysLeft;         // 정기점검일까지 남은 일수
    private String fcmTokenId;    // FCM 토큰값
}
