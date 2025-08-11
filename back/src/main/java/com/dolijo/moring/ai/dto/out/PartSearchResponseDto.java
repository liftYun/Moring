package com.dolijo.moring.ai.dto.out;

import com.querydsl.core.annotations.QueryProjection;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.*;

import java.util.List;

@Getter
@NoArgsConstructor
@Builder
public class PartSearchResponseDto {

    private Long partId;

    private String nameEn;

    private String nameKo;

    @QueryProjection
    public PartSearchResponseDto(Long partId, String nameEn, String nameKo) {
        this.partId = partId;
        this.nameEn = nameEn;
        this.nameKo = nameKo;
    }
}
