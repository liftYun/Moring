package com.dolijo.moring.pdf;

import lombok.extern.log4j.Log4j2;
import org.apache.pdfbox.Loader;
import org.apache.pdfbox.io.RandomAccessRead;
import org.apache.pdfbox.io.RandomAccessReadBuffer;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.rendering.PDFRenderer;
import org.apache.pdfbox.text.PDFTextStripper;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.client.advisor.vectorstore.QuestionAnswerAdvisor;
import org.springframework.ai.document.Document;
import org.springframework.ai.rag.retrieval.search.VectorStoreDocumentRetriever;
import org.springframework.ai.reader.TextReader;
import org.springframework.ai.reader.pdf.PagePdfDocumentReader;
import org.springframework.ai.reader.pdf.config.PdfDocumentReaderConfig;
import org.springframework.ai.transformer.splitter.TokenTextSplitter;
import org.springframework.ai.vectorstore.SearchRequest;
import org.springframework.ai.vectorstore.VectorStore;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.core.io.Resource;

import java.awt.image.BufferedImage;
import java.io.IOException;
import java.util.List;
import java.util.function.Consumer;
import java.util.stream.Collectors;
import org.springframework.ai.document.Document;
import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(properties = {
        "spring.ai.vectorstore.redis.host=localhost",
        "spring.ai.vectorstore.redis.port=6379",
        "spring.ai.vectorstore.redis.password=ssafy0612!",
        "spring.ai.vectorstore.redis.initialize-schema=true",
        "spring.ai.vectorstore.redis.index=moring-pdf-ko-v1",
        "spring.ai.vectorstore.redis.prefix=moring:pdf:ko:v1:"
})
@Log4j2
class PdfRagIntegrationTest {

    @Autowired
    private VectorStore vectorStore;

    @Qualifier("gmsChatClientBuilder")
    @Autowired
    private ChatClient.Builder chatBuilder;

    // 테스트용 PDF 위치: src/test/resources/rag/pdf/moring.pdf (원하는 이름으로)
//    @Value("classpath:pdf/Moring_Traffic_Safety_Guide_2024.pdf")
    @Value("classpath:pdf/rag1-ocr.pdf")
    private Resource pdf;

    @Value("classpath:rag/rag.txt")
    Resource simpleText;

    private static final String CATEGORY = "pdf/Moring_Traffic_Safety_Guide_2024.pdf";


    //통과
    @DisplayName("VectorStore 구현체가 RedisVectorStore인지 확인")
    @Test
    void t01_vectorStoreShouldBeRedis() {
        log.info("vectorStore.class = {}", vectorStore.getClass().getName());
        assertThat(vectorStore.getClass().getName())
                .isEqualTo("org.springframework.ai.vectorstore.redis.RedisVectorStore");
    }
    //통과
    @DisplayName("Redis 설정 확인 로그 (index/prefix)")
    @Test
    void t02_logRedisIndexAndPrefix() {
        String index = System.getProperty("spring.ai.vectorstore.redis.index",
                System.getenv().getOrDefault("SPRING_AI_VECTORSTORE_REDIS_INDEX", "N/A"));
        String prefix = System.getProperty("spring.ai.vectorstore.redis.prefix",
                System.getenv().getOrDefault("SPRING_AI_VECTORSTORE_REDIS_PREFIX", "N/A"));

        log.info("redis.index  = {}", index);
        log.info("redis.prefix = {}", prefix);

        // 위 System.getProperty 방식이 비었으면 테스트 properties에서 주입한 상수가 적용되는지만 확인
        // (그냥 로그로 눈으로만 확인해도 충분)
        assertThat(index).isNotEmpty();
    }
    // 실패
    @DisplayName("PagePdfDocumentReader: 페이지 단위 추출 확인")
    @Test
    void t03_pageReaderShouldProduceDocs() {
        var reader = new PagePdfDocumentReader(
                pdf,
                PdfDocumentReaderConfig.builder()
                        .withPagesPerDocument(1)
                        // 마진 옵션은 일단 제거하여 순정 추출이 되는지 먼저 확인
                        .build()
        );
        List<Document> pages = reader.read();
        log.info("pages.size = {}", pages.size());
        if (!pages.isEmpty()) {
            String first = pages.get(0).getText();
            log.info("firstPage.len = {}", first == null ? -1 : first.length());
            if (first != null && !first.isEmpty()) {
                log.info("firstPage.sample = {}", first.substring(0, Math.min(200, first.length())));
            }
        }
        assertThat(pages.size()).isGreaterThan(0); // 실패 시 PDFBox가 텍스트를 못 뽑고 있는 것
    }


    @org.junit.jupiter.api.Test
    @org.junit.jupiter.api.DisplayName("PDFBox 3.x: byte[]로 로드")
    void t03b_pdfboxRawExtractionShouldProduceText_bytes() throws Exception {
        try (java.io.InputStream in = pdf.getInputStream()) {
            byte[] bytes = in.readAllBytes();                 // ✅ InputStream → byte[]
            try (PDDocument doc = Loader.loadPDF(bytes)) {    // ✅ byte[] 오버로드 사용
                PDFTextStripper stripper = new PDFTextStripper();
                String all = stripper.getText(doc);
                log.info("pdfbox.totalLen = {}", all == null ? -1 : all.length());
                if (all != null && !all.isEmpty()) {
                    log.info("pdfbox.sample = {}", all.substring(0, Math.min(300, all.length())));
                }
                org.assertj.core.api.Assertions.assertThat(all).isNotNull();
                org.assertj.core.api.Assertions.assertThat(all.length()).isGreaterThan(0);
            }
        }
    }

//    @Test
//    void ingestPdfOnce() {
//        log.info("pdf.exists = {}", pdf.exists());
//        log.info("pdf.filename = {}", pdf.getFilename());
//        // 깨끗하게 넣고 싶으면 아래 한 줄 유지(완전 초기화 원치 않으면 주석 처리)
//        vectorStore.delete("category == '" + CATEGORY + "'");
//
//        // 1) PDF를 페이지 단위로 읽기
//        PagePdfDocumentReader reader = new PagePdfDocumentReader(
//                pdf,
//                PdfDocumentReaderConfig.builder()
//                        .withPagesPerDocument(1)     // 페이지 1개 = Document 1개
//                        .withPageTopMargin(0)        // 필요시 헤더 제거용 마진 조정
//                        .build()
//        );
//        List<Document> pageDocs = reader.read();
//        log.info("pages = {}", pageDocs.size());
//
//        // 2) 텍스트 청크로 분할
//        TokenTextSplitter splitter = TokenTextSplitter.builder()
//                .withChunkSize(1000)        // ✅ chunkSize(...)
//                .withMinChunkSizeChars(350) // ✅ minChunkSizeChars(...)
//                //.overlap(150)            // ❌ 이 메서드는 네 버전에 없음
//                .withKeepSeparator(true)    // 선택
//                .build();
//
//        List<Document> chunks = splitter.split(pageDocs);
//
//        // 3) 메타데이터(필터용) 부여
//        chunks.forEach(d -> {
//            d.getMetadata().put("category", CATEGORY);
//            // 선택: 원본 파일명/페이지 등 추가
//            // d.getMetadata().put("source", pdf.getFilename());
//        });
//
//        // 4) 벡터스토어에 영구 저장 (Redis volume으로 영속)
//        vectorStore.add(chunks);
//    }
@Test
void ingestPdfOnce_pdfboxDirect() throws Exception {
    log.info("pdf.exists = {}", pdf.exists());
    log.info("pdf.filename = {}", pdf.getFilename());

    vectorStore.delete("category == '" + CATEGORY + "'");

    String text;
    try (var in = pdf.getInputStream();
         RandomAccessRead rar = new RandomAccessReadBuffer(in);   // ✅ InputStream → RandomAccessRead
         PDDocument pdDoc = Loader.loadPDF(rar)) {                // ✅ RandomAccessRead 오버로드 사용
        PDFTextStripper stripper = new PDFTextStripper();
        text = stripper.getText(pdDoc);
    }
    if (text == null || text.isBlank()) {
        log.warn("PDF 텍스트 추출 실패");
        return;
    }

    // Document 생성
    var doc = new org.springframework.ai.document.Document(text);
    doc.getMetadata().put("category", CATEGORY);

    // 청크 분할
    var splitter = org.springframework.ai.transformer.splitter.TokenTextSplitter.builder()
            .withChunkSize(1000)
            .withMinChunkSizeChars(350)
            .withKeepSeparator(true)
            .build();
    var chunks = splitter.split(List.of(doc));

    // 벡터스토어 저장
    vectorStore.add(chunks);
    log.info("인제스트 완료: {} chunks 저장", chunks.size());
}


    @Test
    public void textReaderTest() throws IOException {
        // TODO: 11-2. simpleText 문서를 읽어서 DB에 저장하자.
        // 이때 meta field로 category=json을 설정한다.
        vectorStore.delete("category == '" + CATEGORY + "'");

        TextReader textReader = new TextReader(simpleText);
        textReader.getCustomMetadata().put("category", "text");

        TokenTextSplitter splitter = new TokenTextSplitter();
        List<Document> list = splitter.apply(textReader.get());

        vectorStore.add(list);
    }

//    @Test
//    void simpleTest() {
//        String user = "임의 결석을 4회 했을 때 수강생의 운명은 어떻게 될까?";
//        Consumer<ChatClient.AdvisorSpec> spec = a -> a.param(QuestionAnswerAdvisor.FILTER_EXPRESSION, "category=='text'");
//        String result1 = chatService.ragGeneration(user, true,  spec);
//        log.debug("과연 그는: {}", result1);
//    }

    @Test
    void askWithRag() {
        var sr = SearchRequest.builder()
                .query("첨단운전자 보조 시스템 운전자 안전수칙은?")
                .topK(5)
                .similarityThreshold(0.0) // ✅ threshold 제거
                //.filterExpression("category == '" + CATEGORY + "'")
                .build();

        var hits = vectorStore.similaritySearch(sr);

        if (hits.isEmpty()) {
            log.warn("검색 결과 없음");
        } else {
            for (var hit : hits) {
                log.info("hit score = {}", hit.getScore());
                log.info("hit text = {}", hit.getText() != null ? hit.getText() : hit.getFormattedContent());
            }
        }

        // ✅ context 생성
        String context = hits.stream()
                .map(d -> d.getText() != null ? d.getText() : d.getFormattedContent())
                .collect(java.util.stream.Collectors.joining("\n---\n"));
        log.info("context = {}", context);

        String system = """
    다음 컨텍스트만 근거로 정확하고 간결하게 답하라.
    모르면 모른다고 답하라.
    """;

        String answer = chatBuilder.build()
                .prompt()
                .system(system + "\n\n컨텍스트:\n" + context)
                .user("2023년 10월 19일 동법 시행규칙 알려줘.") // ✅ LLM 최종 질문
                .call()
                .content();

        org.assertj.core.api.Assertions.assertThat(answer).isNotBlank();
        System.out.println("RAG 답변: " + answer);
    }


    @Test
    void askWithRag_viaAdvisor() {
        var searchRequest = SearchRequest.builder()
                .topK(5)
                .similarityThreshold(0.0)
                .filterExpression("category == 'text'")
                .build();

        var advisor = QuestionAnswerAdvisor.builder(vectorStore)
                .searchRequest(searchRequest)
                .build();

        Consumer<ChatClient.AdvisorSpec> spec = a -> a.advisors(advisor);

        String user = "교통환경 어떻게 바뀌고 있나? 핵심만 3줄로 요약해줘.";
        //String answer = chatService.ragGeneration(user, true, spec);
    }



}
