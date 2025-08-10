package com.dolijo.moring.ai.dto.out;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;
import java.util.List;

@Getter
@AllArgsConstructor
@Builder
public class PartIdResolveResponseDto {
    private LocalDateTime changedAt;     // OCR에서 온 교환일시
    private List<Long> partIdList;       // 매핑된 부품 ID 리스트 (중복 제거)
}