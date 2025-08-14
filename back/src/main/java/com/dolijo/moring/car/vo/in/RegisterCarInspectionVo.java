package com.dolijo.moring.car.vo.in;

import com.dolijo.moring.car.dto.in.RegisterCarInspectionDto;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.Setter;
import java.time.LocalDate;

@Getter
@AllArgsConstructor
public class RegisterCarInspectionVo {
    @Schema(description = "점검일 (YYYY-MM-DD)", example = "2025-08-07", required = true)
    private LocalDate inspectionDate;

//    @Schema(description = "부적합 내용", example = "")
//    private String inadequateDetails;
//
//    @Schema(description = "시정권고 내용", example = "")
//    private String recommendationDetails;
//
//    @Schema(description = "자기진단(기센서점검)", example = "고객님의 차량은 정상입니다.")
//    private String selfDiagnosis;
//
//    @Schema(description = "특기사항", example = "장거리 운행 예정")
//    private String specialNotes;

    // DTO 변환 메서드
    public RegisterCarInspectionDto toDto() {
        return RegisterCarInspectionDto.builder()
                .inspectionDate(this.inspectionDate)
//                .inadequateDetails(isNullOrBlank(this.inadequateDetails) ? null : this.inadequateDetails)
//                .recommendationDetails(isNullOrBlank(this.recommendationDetails) ? null : this.recommendationDetails)
//                .selfDiagnosis(isNullOrBlank(this.selfDiagnosis) ? null : this.selfDiagnosis)
//                .specialNotes(isNullOrBlank(this.specialNotes) ? null : this.specialNotes)
                .build();
    }
    private boolean isNullOrBlank(String value) {
        return value == null || value.trim().isEmpty();
    }
}
