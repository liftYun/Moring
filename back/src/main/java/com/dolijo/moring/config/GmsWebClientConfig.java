package com.dolijo.moring.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.function.client.WebClient;

@Configuration
public class GmsWebClientConfig {

    @Bean
    public WebClient gmsWebClient() {
        return WebClient.builder()
                .baseUrl("https://gms.ssafy.io/gmsapi/api.openai.com/v1")
                .build();
    }
}
