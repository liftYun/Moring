package com.dolijo.moring.config;

import lombok.extern.log4j.Log4j2;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.openai.OpenAiChatModel;
import org.springframework.ai.openai.OpenAiChatOptions;
import org.springframework.ai.openai.api.OpenAiApi;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.http.HttpHeaders;
import org.springframework.http.client.ClientHttpRequestInterceptor;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.reactive.function.client.ExchangeFilterFunction;
import org.springframework.web.reactive.function.client.WebClient;

import java.net.URI;
import java.util.HashMap;
import java.util.Map;


@Log4j2
@Configuration
public class GmsOpenAiConfig {

    @Bean
    @Primary
    public ChatClient.Builder gmsChatClientBuilder(
            @Value("${gms.gateway.key}") String gmsKey
    ) {
        ClientHttpRequestInterceptor logInterceptor = (req, body, exec) -> {
            URI uri = req.getURI();
            HttpHeaders safe = new HttpHeaders();
            safe.putAll(req.getHeaders());
            if (safe.containsKey(HttpHeaders.AUTHORIZATION)) {
                safe.set(HttpHeaders.AUTHORIZATION, "Bearer ***");
            }
            return exec.execute(req, body);
        };
        // RestClient 빌더 생성 (위의 로깅 인터셉터 적용)
        RestClient.Builder restClientBuilder = RestClient.builder()
                .requestInterceptor(logInterceptor);

        // --- WebClient 로깅 필터 (stream용) ---
        ExchangeFilterFunction webLogFilter = ExchangeFilterFunction.ofRequestProcessor(clientRequest -> {
            var safe = new LinkedMultiValueMap<>(clientRequest.headers());
            safe.remove(HttpHeaders.AUTHORIZATION);
            return reactor.core.publisher.Mono.just(clientRequest);
        });
        WebClient.Builder webClientBuilder = WebClient.builder().filter(webLogFilter);

        // OpenAiApi 객체 생성
        OpenAiApi api = OpenAiApi.builder()
                .apiKey(gmsKey)
                .baseUrl("https://gms.ssafy.io/gmsapi/")
                .completionsPath("api.openai.com/v1/chat/completions")
                .embeddingsPath("api.openai.com/v1/embeddings")
                .restClientBuilder(restClientBuilder)
                .webClientBuilder(webClientBuilder)
                .build();

        // 옵션: User-Agent/Accept 만 추가 (Host 넣으면 에러남)
        Map<String, String> extraHeaders = new HashMap<>();
        extraHeaders.put("User-Agent", "curl/8.6.0");
        extraHeaders.put("Accept", "application/json");

        OpenAiChatOptions options = OpenAiChatOptions.builder()
                .model("gpt-4o-mini")
                .temperature(0.1)
                .httpHeaders(extraHeaders)
                .build();

        OpenAiChatModel model = OpenAiChatModel.builder()
                .openAiApi(api)
                .defaultOptions(options)
                .build();

        return ChatClient.builder(model);
    }

    @Bean
    public ChatClient gmsChatClient(ChatClient.Builder builder) {
        return builder.build();
    }
}