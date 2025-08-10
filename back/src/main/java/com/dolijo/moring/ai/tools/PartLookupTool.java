package com.dolijo.moring.ai.tools;

import com.dolijo.moring.ai.dto.out.PartSearchResponseDto;
import com.dolijo.moring.part.repository.PartDslRepository;
import com.dolijo.moring.part.service.PartService;       // ← 실제 조회 서비스
import lombok.RequiredArgsConstructor;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.stereotype.Component;

import java.util.List;


@Component
@RequiredArgsConstructor
public class PartLookupTool {

    private final PartService partService;
    private final PartDslRepository partDslRepository;


    @Tool(description = "OCR로 추출된 부품명과 비교를 위해 RDB의 부품 테이블의 정보를 RAG를 위해 조회")
    public List<PartSearchResponseDto> findPartCandidatesByName(String partName) {
        return partDslRepository.findAllPartsAsSearchDto();
    }
}