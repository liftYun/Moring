package com.dolijo.moring.car.vo.out;

import lombok.Builder;
import lombok.Getter;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Getter
@Builder
public class CarInspectionLogResponseVo {
    private final LocalDateTime inspectionDateTime;
    private final String inspectionStatus; // enum의 description을 String으로 반환
//    private final String inadequateDetails;
//    private final String recommendationDetails;
//    private final String selfDiagnosis;
//    private final String specialNotes;

    @Builder
    public CarInspectionLogResponseVo(LocalDateTime inspectionDateTime, String inspectionStatus) {
        this.inspectionDateTime = inspectionDateTime;
        this.inspectionStatus = inspectionStatus;
//        this.inadequateDetails = inadequateDetails;
//        this.recommendationDetails = recommendationDetails;
//        this.selfDiagnosis = selfDiagnosis;
//        this.specialNotes = specialNotes;
    }
}
