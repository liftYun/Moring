package com.dolijo.moring.sms.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class EmergencyRequestDto {
    @Schema(description = "차대 번호", example = "KNMK5C2HMLP000437")
    private String vin;

    @Schema(description = "위도", example = "37.5665")
    private Double latitude;

    @Schema(description = "경도", example = "126.9780")
    private Double longitude;

    @Schema(description = "주소", example = "서울특별시 중구 세종대로 110", nullable = true)
    private String address;
}

