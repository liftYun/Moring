package com.dolijo.moring.part.dto.in;

import com.dolijo.moring.part.entity.valueobject.PartType;
import lombok.*;

@Getter
@NoArgsConstructor
public class RegisterPartRequestDto {
    private String nameKo;
    private String nameEn;
    private int recommendedCycleMonths;
    private Integer recommendedCycleKm;
    private PartType type;
    private String description;

    @Builder
    public RegisterPartRequestDto(String nameKo, String nameEn, int recommendedCycleMonths, Integer recommendedCycleKm, PartType type, String description) {
        this.nameKo = nameKo;
        this.nameEn = nameEn;
        this.recommendedCycleMonths = recommendedCycleMonths;
        this.recommendedCycleKm = recommendedCycleKm;
        this.type = type;
        this.description = description;
    }
}
