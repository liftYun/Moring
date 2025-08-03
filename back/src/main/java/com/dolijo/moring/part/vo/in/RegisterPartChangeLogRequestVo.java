package com.dolijo.moring.part.vo.in;

import com.dolijo.moring.part.dto.in.RegisterPartChangeLogRequestDto;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.*;

import java.time.LocalDateTime;

@Getter
@Builder
public class RegisterPartChangeLogRequestVo {

    @Schema(description = "차대번호(VIN)", required = true, example = "KNMK5C2HMLP000437", maxLength = 60)
    private final String vin;

    @Schema(description = "부품 ID", required = true, example = "1")
    private final Long partId;

    @Schema(description = "교환 일시", required = false, example = "2025-07-30T14:55:00")
    private final LocalDateTime createdAt;

    public RegisterPartChangeLogRequestDto toDto() {
        return RegisterPartChangeLogRequestDto.builder()
                .vin(this.vin)
                .partId(this.partId)
                .createdAt(this.createdAt)   // createdAt도 dto로 넘김
                .build();
    }
}
