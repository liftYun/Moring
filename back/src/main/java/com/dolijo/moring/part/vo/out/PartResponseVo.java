package com.dolijo.moring.part.vo.out;

import com.dolijo.moring.part.dto.out.PartResponseDto;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.*;

@Getter
@Builder
public class PartResponseVo {

    @Schema(description = "부품 ID", example = "1")
    private final Long id;

    @Schema(description = "한글 부품명", example = "엔진오일")
    private final String nameKo;

    @Schema(description = "영어 부품명", example = "Engine Oil")
    private final String nameEn;

    @Schema(description = "권장 교체주기(월)", example = "6")
    private final Integer recommendedCycleMonths;

    @Schema(description = "권장 교체주기(km, null 허용)", example = "10000")
    private final Integer recommendedCycleKm;

    @Schema(description = "부품 유형", example = "CONSUMABLE")
    private final String type;

    @Schema(description = "부품 설명", example = "엔진 보호를 위해 주기적으로 교환해야 하는 오일입니다.")
    private final String description;

    public static PartResponseVo from(PartResponseDto dto) {
        return PartResponseVo.builder()
                .id(dto.getId())
                .nameKo(dto.getNameKo())
                .nameEn(dto.getNameEn())
                .recommendedCycleMonths(dto.getRecommendedCycleMonths())
                .recommendedCycleKm(dto.getRecommendedCycleKm())
                .type(dto.getType().getDescription())
                .description(dto.getDescription())
                .build();
    }
}
