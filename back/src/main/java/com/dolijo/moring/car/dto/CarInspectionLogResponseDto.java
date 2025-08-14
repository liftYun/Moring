package com.dolijo.moring.car.dto;

import com.dolijo.moring.car.valueobject.InspectionStatus;
import com.dolijo.moring.car.vo.out.CarInspectionLogResponseVo;
import com.querydsl.core.annotations.QueryProjection;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Getter
@Builder
public class CarInspectionLogResponseDto {
    private final LocalDateTime inspectionDateTime;
    private final InspectionStatus inspectionStatus;
//    private final String inadequateDetails;
//    private final String recommendationDetails;
//    private final String selfDiagnosis;
//    private final String specialNotes;

    @QueryProjection
    public CarInspectionLogResponseDto(LocalDateTime inspectionDateTime, InspectionStatus inspectionStatus) {
        this.inspectionDateTime = inspectionDateTime;
        this.inspectionStatus = inspectionStatus;
    }

    public CarInspectionLogResponseVo toVo() {
        return CarInspectionLogResponseVo.builder()
                .inspectionDateTime(this.inspectionDateTime)
                .inspectionStatus(this.inspectionStatus.getDescription()) // enum의 description 사용
                .build();
    }
}
