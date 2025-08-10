package com.dolijo.moring.ai.service;

import com.dolijo.moring.ai.dto.out.OcrPartChangeLogExtractedDto;
import com.dolijo.moring.ai.tools.PartLookupTool;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

/**
 * Swagger에서 바로 때려볼 테스트용 서비스
 * - @Tool(PartLookupTool)을 ChatClient에 등록하고
 * - LLM이 각 부품명으로 툴을 호출해 DB 파트 ID를 정규화하도록 유도
 */
@Service
@RequiredArgsConstructor
@Log4j2
public class PartMappingTestService {

    @Qualifier("gmsChatClient")              // 빈 이름은 환경에 맞게(예: 너가 쓰는 ChatClient 빈)
    private final ChatClient chatClient;

    private final PartLookupTool partLookupTool;
    private final ObjectMapper om = new ObjectMapper();

    @Value("${spring.ai.dms.safety-prompt}")
    private String safetyPrompt;

    /**
     * OCR 결과의 partNameList를 DB Part ID 리스트로 정규화
     * LLM 응답은 반드시 {"ids":[...]} JSON 으로만 반환하도록 강하게 지시
     */
    public List<Long> mapPartNamesToIds(OcrPartChangeLogExtractedDto ocr) {
        List<String> names = ocr.getPartNameList();

        String userPrompt = """
            아래는 OCR로 추출된 자동차 교체 부품명 리스트다.
            각 항목에 대해 DB를 질의하는 툴(searchPartByName)을 사용해서 가장 적절한 파트 ID 1개씩만 고르라.
            - 정확히 일치하는게 없으면 가장 유사한 후보 중 1개를 선택
            - 전혀 매칭이 어려우면 해당 항목은 건너뛰기
            - 결과는 오직 JSON으로만 출력: {"ids":[<long>...]}
            - 설명/문장/마크다운 절대 금지
            부품명 리스트:
            %s
            """.formatted(String.join(", ", names));

        String content = chatClient
                .prompt()
                .system(safetyPrompt + "\n답변은 반드시 2~3문장 이내 또는 JSON만. 지금은 JSON만 반환.")
                .user(userPrompt)
                .tools(partLookupTool) // ← @Tool 등록
                .call()
                .content();

        // JSON 파싱
        try {
            JsonNode node = om.readTree(content);
            JsonNode ids = node.path("ids");
            return om.convertValue(ids, om.getTypeFactory().constructCollectionType(List.class, Long.class));
        } catch (Exception e) {
            log.warn("LLM 응답 JSON 파싱 실패 content={}", content, e);
            throw new IllegalStateException("LLM 응답 파싱 실패");
        }
    }
}
