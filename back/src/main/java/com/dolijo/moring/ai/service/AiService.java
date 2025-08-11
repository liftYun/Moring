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

    @Qualifier("gmsChatClientBuilder")
    private final ChatClient.Builder chatBuilder;
    private final PartLookupTool partLookupTool; // @Tool 등록된 컴포넌트


    @Value("${prompt.part-id-resolve-prompt}")
    private String partIdResolvePrompt;



    /**
     * OCR 결과(교환일시 + 부품명 리스트)를 받아
     * - LLM+툴콜로 부품명 → 표준 부품ID 매핑
     * - 최종 DTO(교환일시+ID리스트) 반환
     */
    public PartIdResolveResponseDto resolvePartIdsWithLlm(OcrPartChangeLogExtractedDto ocr) {
        final List<String> ocrNames = Optional.ofNullable(ocr.getPartNameList()).orElseGet(List::of);

        // 빈 입력 방어
        if (ocrNames.isEmpty()) {
            return PartIdResolveResponseDto.builder()
                    .changedAt(ocr.getChangedAt())
                    .partIdList(List.of())
                    .build();
        }

        // 프롬프트 구성
        final String userMessage = buildUserMessage(ocr);
        log.info("clova ocr결과 -> llm판단용 입력: {}", userMessage);

        // LLM 호출
        final LlmPartIdsOnly result = chatBuilder
                .build()
                .prompt()
                .system(partIdResolvePrompt) // yml에서 관리
                .tools(partLookupTool)
                .user(userMessage)
                .call()
                .entity(LlmPartIdsOnly.class);

        // 결과 정리
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

    private String buildUserMessage(OcrPartChangeLogExtractedDto ocr) {
        final String changedAtIso = Optional.ofNullable(ocr.getChangedAt())
                .map(dt -> dt.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME))
                .orElse("null");

        final List<String> names = Optional.ofNullable(ocr.getPartNameList()).orElseGet(List::of);
        // names.forEach();
        return """
                {
                      "changedAt": "%s",
                      "ocrPartNames": %s
                }
                """.formatted(changedAtIso, names.toString());
    }



}
