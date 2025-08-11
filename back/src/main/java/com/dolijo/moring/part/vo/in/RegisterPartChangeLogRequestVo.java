package com.dolijo.moring.part.vo.in;

import com.dolijo.moring.part.dto.in.RegisterPartChangeLogRequestDto;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.*;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Getter
@AllArgsConstructor
@Builder
@Schema(description = "부품 교환 이력")
public class RegisterPartChangeLogRequestVo {
    @Schema(description = "차대번호(VIN)", required = true, example = "KNMK5C2HMLP000437", maxLength = 60)
    private String vin;

    @Schema(description = "부품 교환 일시", required = true, example = "2025-07-30T14:55:00")
    private LocalDateTime changedAt;

    @Schema(description = "부품 ID 리스트", required = true)
    private List<Long> partIdList;

    public static RegisterPartChangeLogRequestDto from(RegisterPartChangeLogRequestVo vo) {
        return RegisterPartChangeLogRequestDto.builder()
                .vin(vo.vin)
                .changedAt(vo.changedAt)
                .partIdList(vo.partIdList)
                .build();
    }


}
