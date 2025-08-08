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
    private final String inadequateDetails;
    private final String recommendationDetails;
    private final String selfDiagnosis;
    private final String specialNotes;

    @QueryProjection
    public CarInspectionLogResponseDto(LocalDateTime inspectionDateTime, InspectionStatus inspectionStatus,
                                       String inadequateDetails, String recommendationDetails,
                                       String selfDiagnosis, String specialNotes) {
        this.inspectionDateTime = inspectionDateTime;
        this.inspectionStatus = inspectionStatus;
        this.inadequateDetails = inadequateDetails;
        this.recommendationDetails = recommendationDetails;
        this.selfDiagnosis = selfDiagnosis;
        this.specialNotes = specialNotes;
    }

    public CarInspectionLogResponseVo toVo() {
        return CarInspectionLogResponseVo.builder()
                .inspectionDateTime(this.inspectionDateTime)
                .inspectionStatus(this.inspectionStatus.getDescription()) // enum의 description 사용
                .inadequateDetails(this.inadequateDetails)
                .recommendationDetails(this.recommendationDetails)
                .selfDiagnosis(this.selfDiagnosis)
                .specialNotes(this.specialNotes)
                .build();
    }
}
