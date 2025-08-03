package com.dolijo.moring.car.dto;

import com.dolijo.moring.car.valueobject.InspectionStatus;
import com.dolijo.moring.car.vo.out.CarInspectionLogResponseVo;
import com.querydsl.core.annotations.QueryProjection;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDate;

@Getter
@Builder
public class CarInspectionLogResponseDto {
    private final LocalDate inspectionDate;
    private final InspectionStatus inspectionStatus;

    @QueryProjection
    public CarInspectionLogResponseDto(LocalDate inspectionDate, InspectionStatus inspectionStatus) {
        this.inspectionDate = inspectionDate;
        this.inspectionStatus = inspectionStatus;
    }

    public CarInspectionLogResponseVo toVo() {
        return CarInspectionLogResponseVo.builder()
                .inspectionDate(this.inspectionDate)
                .inspectionStatus(this.inspectionStatus.getDescription()) // enum의 description 사용
                .build();
    }
}
