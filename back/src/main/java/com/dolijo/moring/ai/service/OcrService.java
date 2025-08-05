package com.dolijo.moring.ai.service;

import com.dolijo.moring.ai.vo.out.CarRegistrationOcrResponseVo;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.List;
import java.util.Map;


@Service
public class OcrService {

    private final WebClient gmsWebClient;
    private final GptService gptService;

    private final String gmsKey;

    public OcrService(
            WebClient gmsWebClient,
            GptService gptService,
            @Value("${spring.ai.openai.api-key}") String gmsKey
    ) {
        this.gmsWebClient = gmsWebClient;
        this.gmsKey = gmsKey;
        this.gptService = gptService;
    }


    public String ask(String prompt) {  Map<String, Object> body = Map.of(
            "model", "gpt-4o-mini",
            "messages", List.of(
                    Map.of("role", "system", "content", "You are a helpful assistant."),
                    Map.of("role", "user", "content", prompt)
            )
    );

        Map response = gmsWebClient.post()
                .uri("/chat/completions")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + gmsKey)
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(body)
                .retrieve()
                .bodyToMono(Map.class)
                .block();

        // content 추출만 간단하게
        try {
            var choices = (List<Map<String, Object>>) response.get("choices");
            return (String) ((Map<String, Object>) choices.get(0).get("message")).get("content");
        } catch (Exception e) {
            return response != null ? response.toString() : "No response";
        }
    }

    public CarRegistrationOcrResponseVo ocrCarRegistration(byte[] imageBytes) throws Exception {
        System.out.println("444!!!");
        String base64Image = java.util.Base64.getEncoder().encodeToString(imageBytes);
        String prompt = """
            아래 이미지는 차량 등록증입니다.
            - 주민등록번호, 차량소유자 등 민감한 정보는 반드시 '***'로 마스킹해서 출력하세요.
            - 나머지 주요 차량 정보만 아래 JSON 형태로 정확히 추출해주세요.
            예시: { \"vin\": \"...\", \"modelName\": \"...\", \"registeredAt\": \"...\" }
            """;
        Map<String, Object> body = Map.of(
            "model", "gpt-4o-mini",
            "messages", List.of(
                Map.of("role", "system", "content", "You are a helpful assistant."),
                Map.of("role", "user", "content", prompt),
                Map.of("role", "user", "content", base64Image)
            )
        );
        Map response = gmsWebClient.post()
                .uri("/chat/completions")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + gmsKey)
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(body)
                .retrieve()
                .bodyToMono(Map.class)
                .block();
        try {
            var choices = (List<Map<String, Object>>) response.get("choices");
            String content = (String) ((Map<String, Object>) choices.get(0).get("message")).get("content");
            ObjectMapper mapper = new ObjectMapper();
            return mapper.readValue(content, CarRegistrationOcrResponseVo.class);
        } catch (Exception e) {
            throw new RuntimeException("OCR 응답 파싱 실패: " + response);
        }
    }
    public CarRegistrationOcrResponseVo carRegistrationOcr(MultipartFile image) throws Exception {
        byte[] imageBytes = image.getBytes();
        System.out.println("333!!!");
        return ocrCarRegistration(imageBytes);
    }
}
