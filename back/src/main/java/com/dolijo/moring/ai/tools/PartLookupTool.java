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

    private final PartDslRepository partDslRepository;

    @Tool(
            name = "findPartCandidatesByNames",
            description = "입력된 부품명과 유사한 표준 부품 후보를 DB에서 조회하여 반환." +
                    "이 툴은 LLM이 부품 후보를 찾기 위해 사용됩니다." +
                    "부품은 20개 이하이니 해당 Tool은 한번만 사용합니다."
    )    public List<PartSearchResponseDto> findAllPartsAsSearchDto() {
        return partDslRepository.findAllPartsAsSearchDto();
    }
}