package com.dolijo.moring.car.dto.in;

import lombok.Builder;
import lombok.Getter;
import java.time.LocalDate;

@Getter
public class RegisterCarInspectionDto {
    private final LocalDate inspectionDate;
    private final String inadequateDetails;
    private final String recommendationDetails;
    private final String selfDiagnosis;
    private final String specialNotes;

    @Builder
    public RegisterCarInspectionDto(LocalDate inspectionDate, String inadequateDetails, String recommendationDetails, String selfDiagnosis, String specialNotes) {
        this.inspectionDate = inspectionDate;
        this.inadequateDetails = inadequateDetails;
        this.recommendationDetails = recommendationDetails;
        this.selfDiagnosis = selfDiagnosis;
        this.specialNotes = specialNotes;
    }
}
