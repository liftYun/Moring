package com.dolijo.moring.ai.tools;

import com.dolijo.moring.ai.service.SafetyAskService;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.ai.vectorstore.SearchRequest;
import org.springframework.ai.vectorstore.VectorStore;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.ai.document.Document;

import java.util.List;
import java.util.stream.Collectors;

@Component
@Log4j2
public class SafeDrivingTipTool {

    private final VectorStore vectorStore;

    // ★★ 반드시 생성자 주입 + Qualifier로 주입을 “고정”합니다.
    public SafeDrivingTipTool(@Qualifier("moringVectorStore") VectorStore vectorStore) {
        this.vectorStore = vectorStore;
    }
    private static final int LIMIT_TOKEN_SIZE = 5000;

    @Tool(
            name = "searchSafetyRag",
            description = "오직 교통/운전 안전 관련 질문일 때만 호출하세요. "
                    + "예: 음주운전 기준(BAC), 안전거리, 어린이보호구역/규정/벌점/벌금/안전운전 조언 등. "
                    + "이 툴은 safety_rag 컬렉션에서 관련 근거 문서를 찾아 요약용 컨텍스트를 반환합니다. "
                    + "일반 지식/기타 질문에는 호출하지 마세요. 한 요청당 한 번만 호출하세요."
    )
    public String getSafeDrivingTip(
            @ToolParam(description = "사용자의 한국어 또는 영어 질문 원문의 RAG에 검색될 교통/운전 안전 관련 핵심 단어") String searchTerm
    ) {
        log.info("[RAG] called with prompt: {}", searchTerm);
        try {
            SearchRequest sr = SearchRequest.builder()
                    .query(searchTerm)
                    .topK(3)
                    .similarityThreshold(0.5)
                    .filterExpression("collection == 'safety_rag'")
                    .build();

            List<Document> hits = vectorStore.similaritySearch(sr);

            if (hits == null || hits.isEmpty()) {
                log.info("RAG 매칭되는 내용 없음: {}", searchTerm);
                return "NO_HITS";
            }
            String context = hits.stream()
                    .map(d -> d.getText() != null ? d.getText() : d.getFormattedContent())
                    .collect(Collectors.joining("\n---\n"));

            if (context.length() > LIMIT_TOKEN_SIZE) {
                context = context.substring(0, LIMIT_TOKEN_SIZE);
            }
            //log.info("context for   {}", context);
            return context;

        } catch (Exception e) {
            log.error("[RAG] similaritySearch EXCEPTION: {}", e.toString(), e);
            return "NO_HITS";
        }
    }


}
