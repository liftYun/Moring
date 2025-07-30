package com.dolijo.moring.part.dto.out;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
@AllArgsConstructor
public class PartStatusListResponseDto {
    private String nameEn;
    private int percentUsed;    // 사용률(%) (0~100)
    private String dueDate;     // 교체 마감일(yyyy-MM-dd), 이력 없으면 null
}
