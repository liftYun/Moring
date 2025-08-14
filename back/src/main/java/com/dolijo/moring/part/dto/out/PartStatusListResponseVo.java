package com.dolijo.moring.part.dto.out;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDate;

@Getter
@Builder
@AllArgsConstructor
public class PartStatusListResponseVo {
    private final Long partId;          // 부품 ID
    private final String nameKo;      // 한글 부품명
    private final int percentUsed;    // 사용률(%) (0~100)
    private final LocalDate dueDate;     // 교체 마감일(yyyy-MM-dd), 이력 없으면 null

    public static PartStatusListResponseVo from(PartStatusListResponseDto dto) {
        return PartStatusListResponseVo.builder()
                .partId(dto.getPartId())
                .nameKo(dto.getNameKo())
                .percentUsed(dto.getPercentUsed())
                .dueDate(dto.getDueDate())
                .build();
    }
}

