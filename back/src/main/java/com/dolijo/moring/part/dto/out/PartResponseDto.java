package com.dolijo.moring.part.dto.out;

import com.dolijo.moring.part.entity.Part;
import com.dolijo.moring.part.entity.valueobject.PartType;
import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PartResponseDto {
    private Long id;
    private String nameKo;
    private String nameEn;
    private int recommendedCycleMonths;
    private Integer recommendedCycleKm;
    private PartType type;
    private String description;

    public static PartResponseDto from(Part entity) {
        return PartResponseDto.builder()
                .id(entity.getId())
                .nameKo(entity.getNameKo())
                .nameEn(entity.getNameEn())
                .recommendedCycleMonths(entity.getRecommendedCycleMonths())
                .recommendedCycleKm(entity.getRecommendedCycleKm())
                .type(entity.getType())
                .description(entity.getDescription())
                .build();
    }
}
