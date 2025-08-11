package com.dolijo.moring.ai.dto.out;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.ToString;

import java.time.LocalDateTime;
import java.util.List;

@Getter
@AllArgsConstructor
@Builder
@ToString
public class OcrPartChangeLogExtractedDto {
    private LocalDateTime changedAt; // 교환일시

    private List<String> partNameList; //  부품 이름 리스트
}

