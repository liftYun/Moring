package com.dolijo.moring.part.vo.in;

import com.dolijo.moring.part.dto.in.RegisterPartRequestDto;
import com.dolijo.moring.part.entity.valueobject.PartType;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.*;

@Getter
@Builder
public class RegisterPartRequestVo {

    @Schema(description = "한글 부품명", required = true, example = "에어필터")
    private final String nameKo;

    @Schema(description = "영어 부품명", required = true, example = "Air Filter")
    private final String nameEn;

    @Schema(description = "권장교체주기(월)", required = true, example = "12")
    private final int recommendedCycleMonths;

    @Schema(description = "권장교체주기(km)", required = false, example = "10000")
    private final Integer recommendedCycleKm;

    @Schema(description = "부품유형 : CONSUMABLE(\"소모품\"), EQUIPMENT(\"장비\"), OTHER(\"기타\")", required = true, example = "CONSUMABLE")
    private final PartType type;

    @Schema(description = "부품 설명", required = false, example = "엔진 내부로 유입되는 공기를 정화해주는 역할을 합니다.")
    private final String description;

    public RegisterPartRequestDto toDto() {
        return RegisterPartRequestDto.builder()
                .nameKo(this.nameKo)
                .nameEn(this.nameEn)
                .recommendedCycleMonths(this.recommendedCycleMonths)
                .recommendedCycleKm(this.recommendedCycleKm)
                .type(this.type)
                .description(this.description)
                .build();
    }
}
