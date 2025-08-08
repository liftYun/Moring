package com.dolijo.moring.ai.service;

import com.dolijo.moring.ai.vo.out.CarRegistrationOcrResponseVo;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.List;
import java.util.Map;


@Service
public class AiService {

    private final WebClient gmsWebClient;

    private final String gmsKey;

    @Value("${spring.ai.dms.safety-prompt}")
    private String safetyPrompt;

    public AiService(
            WebClient gmsWebClient,
            @Value("${spring.ai.openai.api-key}") String gmsKey
    ) {
        this.gmsWebClient = gmsWebClient;
        this.gmsKey = gmsKey;
    }

    /**
     * GPT 메시지 바디 생성 (프롬프트만 입력)
     */
    private Map<String, Object> buildBasicSystemPrompt(String prompt) {
        return Map.of(
            "model", "gpt-4o-mini",
            "messages", List.of(
                Map.of("role", "system", "content", "You are a helpful assistant."),
                Map.of("role", "user", "content", prompt)
            )
        );
    }

    /**
     * GPT 메시지 바디 생성 (프롬프트 + 추가 메시지)
     */
    private Map<String, Object> buildSafetySystemPrompt(String userPrompt) {
        return Map.of(
            "model", "gpt-4o-mini",
            "messages", List.of(
                Map.of("role", "system", "content", safetyPrompt),
                Map.of("role", "user", "content", userPrompt)
            )
        );
    }

    public String safetyAsk(String prompt) {
        Map<String, Object> body = buildSafetySystemPrompt(prompt);

        Map response = gmsWebClient.post()
                .uri("/chat/completions")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + gmsKey)
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(body)
                .retrieve()
                .bodyToMono(Map.class)
                .block();

        try {
            // content 추출
            var choices = (List<Map<String, Object>>) response.get("choices");
            return (String) ((Map<String, Object>) choices.get(0).get("message")).get("content");
        } catch (Exception e) {
            return response != null ? response.toString() : "No response";
        }
    }



}
