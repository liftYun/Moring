package com.dolijo.moring.part.vo.in;

import com.dolijo.moring.part.dto.in.RegisterPartChangeLogRequestDto;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.*;

import java.time.LocalDateTime;

@Getter
@AllArgsConstructor
@Builder
@Schema(description = "부품 교환 이력")
public class RegisterPartChangeLogRequestVo {

    @Schema(description = "차대번호(VIN)", required = true, example = "KNMK5C2HMLP000437", maxLength = 60)
    private String vin;

    @Schema(description = "부품 ID", required = true, example = "1")
    private Long partId;

    @Schema(description = "교환 일시", required = false, example = "2025-07-30T14:55:00")
    private LocalDateTime createdAt;

    public RegisterPartChangeLogRequestDto toDto() {
        return RegisterPartChangeLogRequestDto.builder()
                .vin(this.vin)
                .partId(this.partId)
                .createdAt(this.createdAt)   // createdAt도 dto로 넘김
                .build();
    }
}
