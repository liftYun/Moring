package com.dolijo.moring.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.ai.openai.api.OpenAiApi;

@Configuration
public class OpenAiConfig {

    // application.yml에서 값을 불러와서 생성
    @Bean
    public OpenAiApi openAiApi(
        @Value("${spring.ai.openai.api-key}") String apiKey
    ) {
        // 기본 생성자 (apiKey만 넣어주면 대부분 default로 동작)
        return OpenAiApi.builder()
                .baseUrl("https://gms.ssafy.io/gmsapi")
                .apiKey(apiKey)
                .build();
    }
}
