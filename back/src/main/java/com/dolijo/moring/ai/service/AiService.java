package com.dolijo.moring.ai.service;

import com.dolijo.moring.ai.dto.out.OcrPartChangeLogExtractedDto;
import com.dolijo.moring.ai.dto.out.PartIdResolveResponseDto;
import com.dolijo.moring.ai.dto.system.LlmPartIdsOnly;
import com.dolijo.moring.ai.tools.PartLookupTool;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Log4j2
public class AiService {

    private final @org.springframework.beans.factory.annotation.Qualifier("gmsChatClientBuilder")
    ChatClient.Builder chatBuilder;
    private final PartLookupTool partLookupTool; // @Tool 등록된 컴포넌트


    @Value("${prompt.safety-prompt}")
    private String safetyPrompt;

    public String ask(String userInput) {
        return chatBuilder.build()
                .prompt()
                .system(safetyPrompt)
                .user(userInput)
                .call()
                .content();
    }

    /**
     * OCR 결과(교환일시 + 부품명 리스트)를 받아
     * - LLM+툴콜로 부품명 → 표준 부품ID 매핑
     * - 최종 DTO(교환일시+ID리스트) 반환
     */
    public PartIdResolveResponseDto resolvePartIdsWithLlm(OcrPartChangeLogExtractedDto ocr) {
        final List<String> ocrNames = Optional.ofNullable(ocr.getPartNameList()).orElseGet(List::of);

        // 1) 빈 입력 방어
        if (ocrNames.isEmpty()) {
            return PartIdResolveResponseDto.builder()
                    .changedAt(ocr.getChangedAt())
                    .partIdList(List.of())
                    .build();
        }

        // 2) 프롬프트 구성 (툴 정확한 이름 + '정확히 한 번만 호출' 명시)
        final String userMessage = buildUserMessage(ocr);
        log.info("clova ocr결과 -> llm판단용 입력: {}", userMessage);

        // 3) LLM 호출
        //    - temperature 0: 결정적
        //    - maxTokens 적정치
        //    - tools(partLookupTool): findPartCandidatesByNames '한 번만' 호출하도록 지시
        final LlmPartIdsOnly result = chatBuilder
                .build()
                .prompt()
                .system(SYSTEM_PROMPT_SINGLE_TOOL_CALL)
                .tools(partLookupTool)
                .user(userMessage)
                .call()
                .entity(LlmPartIdsOnly.class);

        // 4) 결과 정리
        final List<Long> ids = Optional.ofNullable(result)
                .map(LlmPartIdsOnly::getPartIdList)
                .orElseGet(List::of)
                .stream()
                .filter(Objects::nonNull)
                .distinct()
                .toList();

        log.info("LLM 매핑 결과 partIdList: {}", ids);

        return PartIdResolveResponseDto.builder()
                .changedAt(ocr.getChangedAt())
                .partIdList(ids)
                .build();
    }

    // ————————————————————————————————————————————————————————————————————————
    // 프롬프트: findPartCandidatesByNames 를 '정확히 1회' 호출하도록 강제
    // 현재 Tool은 파라미터 없이 전체 파트 후보를 반환하므로,
    // LLM이 한 번만 호출해서 메모리에 로드한 뒤, OCR 이름들과 의미적 매칭을 자체 수행하도록 지시한다.
    // ————————————————————————————————————————————————————————————————————————
    private static final String SYSTEM_PROMPT_SINGLE_TOOL_CALL = """
        당신은 자동차 정비 '부품명 표준화/매칭' 전문가입니다.

        작업 목표:
        - OCR에서 추출된 부품명 입력됩니다.
        - 반드시 Tool **findPartCandidatesByNames**를 '정확히 1회'만 호출하여 DB 후보 목록을 불러오고,
          그 결과를 바탕으로 의미적으로 동일한 표준 부품의 partId들을 선별하세요.
        - Tool을 부품명별로 반복 호출하거나 2회 이상 호출하면 안 됩니다. 호출은 딱 한 번!

        매칭 규칙:
        1) 한국어/영어/순서 변경/하이픈/띄어쓰기/약어/동의어 고려 (예: '오일-엔진' == '엔진오일').
        2) 확신 없는 후보는 제외.
        3) 중복 ID 제거.

        출력 형식(엄격):
        - JSON 한 객체만 반환: {"partIdList":[<long>, ...]}
        - 추가 텍스트/설명/코멘트 금지.
        """;

    private String buildUserMessage(OcrPartChangeLogExtractedDto ocr) {
        final String changedAtIso = Optional.ofNullable(ocr.getChangedAt())
                .map(dt -> dt.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME))
                .orElse("null");

        // 배열 그대로 넘겨 LLM이 내부에서 비교·매칭 수행
        final List<String> names = Optional.ofNullable(ocr.getPartNameList()).orElseGet(List::of);

        // 최대한 구조화된 입력을 제공 (LLM이 파싱 실수하지 않도록)
        return """
                {
                  "changedAt": "%s",
                  "ocrPartNames": %s
                }
                """.formatted(changedAtIso, names.toString());
    }



}
