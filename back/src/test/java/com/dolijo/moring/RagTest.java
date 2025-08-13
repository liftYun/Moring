package com.dolijo.moring;


import lombok.extern.log4j.Log4j2;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.client.advisor.vectorstore.QuestionAnswerAdvisor;
import org.springframework.ai.reader.TextReader;
import org.springframework.ai.transformer.splitter.TokenTextSplitter;
import org.springframework.ai.vectorstore.SearchRequest;
import org.springframework.ai.vectorstore.VectorStore;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.ai.document.Document;
import org.springframework.core.io.Resource;

import java.io.IOException;
import java.util.List;
import java.util.function.Consumer;
import java.util.stream.Collectors;

import static org.assertj.core.api.AssertionsForClassTypes.assertThat;


@SpringBootTest()
@Log4j2
class RagTest {

    @Autowired
    @Qualifier("moringVectorStore")
    private VectorStore vectorStore;
    @Value("classpath:rag/rag.txt")
    Resource simpleText;

    @Autowired
    private ChatClient.Builder chatBuilder; // SafetyAskService와 같은 Bean (gmsChatClientBuilder)

    @Value("${prompt.safety-prompt}")
    private String safetyPrompt;

    private static final String CATEGORY = "pdf/Moring_Traffic_Safety_Guide_2024.pdf";



    @Test
    public void textReaderTest() throws IOException { // 1) 기존 'text' 카테고리 문서 삭제 (깨끗한 상태에서 시작)
        vectorStore.delete("category == 'text'");

        // 2) 리소스 읽기
        TextReader textReader = new TextReader(simpleText);

        // 메타데이터 표준화 (아래 참고)
        textReader.getCustomMetadata().put("category", "text");
        textReader.getCustomMetadata().put("collection", "safety_rag");   // ★ 추가 추천
        textReader.getCustomMetadata().put("source", "safety_rag.txt");        // ★ 추가 추천
        textReader.getCustomMetadata().put("lang", "ko");               // ★ 추가 추천

        TokenTextSplitter splitter = new TokenTextSplitter(); // 기본값으로도 OK
        List<Document> list = splitter.apply(textReader.get());

        vectorStore.add(list);
        log.info("인제스트 완료: {} chunks 저장", list.size());
    }


    @Test
    void rag_dui_mini() {
        String userQ = "첨단운전자 보조 시스템 운전자 안전수칙은?";

        // (A) 먼저 리트리버만으로 히트 확인
        SearchRequest sr = SearchRequest.builder()
                .query(userQ)
                .topK(5)
                .similarityThreshold(0.0)
                .filterExpression("collection == 'safety_rag'")
                .build();

        List<Document> hits = vectorStore.similaritySearch(sr);
        log.info("hits.size={}", hits.size());
        hits.forEach(h -> log.info("meta={}, snippet={}", h.getMetadata(),
                (h.getText() == null ? "" : h.getText().substring(0, Math.min(120, h.getText().length())))));

        assertThat(hits).as("히트가 0이면: (1) 스키마에 metadataFields 추가됐는지, (2) 인제스트 문서에 collection='dui-mini'가 들어갔는지 확인")
                .isNotNull();

        // (B) RAG 호출
        String context = hits.stream()
                .map(d -> d.getText() != null ? d.getText() : d.getFormattedContent())
                .collect(Collectors.joining("\n---\n"));


        String answer = chatBuilder.build()
                .prompt()
                .system(safetyPrompt + "\n\n[컨텍스트]\n" + context)
                .user(userQ)
                .call()
                .content();

        log.info("RAG 답변: {}", answer);
        assertThat(answer).isNotBlank();
    }








}
