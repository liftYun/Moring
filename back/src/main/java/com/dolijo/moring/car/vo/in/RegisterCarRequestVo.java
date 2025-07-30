package com.dolijo.moring.car.vo.in;

import com.dolijo.moring.car.dto.in.RegisterCarRequestDto;
import com.fasterxml.jackson.annotation.JsonFormat;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDate;

@Builder
@Getter
public class RegisterCarRequestVo {

    @Schema(description = "차대 번호", example = "KNMK5C2HMLP000437" , requiredMode = Schema.RequiredMode.REQUIRED)
    private String vin;

    @Schema(description = "모델명", example = "XM3", requiredMode = Schema.RequiredMode.REQUIRED , maxLength = 20)
    private String modelName;

    @Schema(description = "애칭", example = "프리티도윤카", requiredMode = Schema.RequiredMode.REQUIRED, maxLength = 30)
    private String nickname;

    @Schema(description = "자동차등록일", example = "2024-01-01", requiredMode = Schema.RequiredMode.REQUIRED)
    private LocalDate registeredAt;  // 등록일

    public RegisterCarRequestDto toDto(){
        return RegisterCarRequestDto.builder()
                .vin(this.getVin())
                .modelName(this.getModelName())
                .nickname(this.nickname)
                .registeredAt(this.getRegisteredAt())
                .build();
    }
}
