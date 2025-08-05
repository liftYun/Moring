package com.dolijo.moring.ai.service;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class GptService {

    private final WebClient gmsWebClient;
    @Value("${spring.ai.openai.api-key}")
    private String gmsKey;

    public String askForCarOcr(String prompt, String base64Image) {
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

        var choices = (List<Map<String, Object>>) response.get("choices");
        if (choices != null && !choices.isEmpty()) {
            var message = (Map<String, Object>) choices.get(0).get("message");
            if (message != null) {
                return String.valueOf(message.get("content"));
            }
        }
        throw new RuntimeException("GPT 응답 없음: " + response);
    }
}
