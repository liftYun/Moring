package com.dolijo.moring.ai.dto.out;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;
import java.util.List;

@Getter
@AllArgsConstructor
@Builder
public class OcrPartChangeLogExtractedDto {
    private LocalDateTime changedAt;

    private List<String> partNameList;
}

