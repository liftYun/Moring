//package com.dolijo.moring.config;
//
//import lombok.extern.log4j.Log4j2;
//import lombok.extern.slf4j.Slf4j;
//import org.springframework.ai.chat.client.ChatClient;
//import org.springframework.ai.openai.OpenAiChatModel;
//import org.springframework.ai.openai.OpenAiChatOptions;
//import org.springframework.ai.openai.api.OpenAiApi;
//import org.springframework.beans.factory.annotation.Value;
//import org.springframework.context.annotation.Bean;
//import org.springframework.context.annotation.Configuration;
//import org.springframework.context.annotation.Primary;
//import org.springframework.http.HttpHeaders;
//import org.springframework.http.client.ClientHttpRequestInterceptor;
//import org.springframework.util.LinkedMultiValueMap;
//import org.springframework.web.client.RestClient;
//import org.springframework.web.reactive.function.client.ExchangeFilterFunction;
//import org.springframework.web.reactive.function.client.WebClient;
//
//import java.net.URI;
//import java.util.HashMap;
//import java.util.Map;
//
//
//@Log4j2
//@Configuration
//public class GmsOpenAiConfig {
//
//    @Bean
//    @Primary
//    public ChatClient.Builder gmsChatClientBuilder(
//            @Value("${gms.gateway.key}") String gmsKey
//    ) {
//        // --- RestClient 로깅 인터셉터 (Authorization 는 마스킹) ---
//        ClientHttpRequestInterceptor logInterceptor = (req, body, exec) -> {
//            URI uri = req.getURI();
//            HttpHeaders safe = new HttpHeaders();
//            safe.putAll(req.getHeaders());
//            if (safe.containsKey(HttpHeaders.AUTHORIZATION)) {
//                safe.set(HttpHeaders.AUTHORIZATION, "Bearer ***");
//            }
//            log.info("[GMS->OpenAI via RestClient] {} {}", req.getMethod(), uri);
//            log.info("[Headers(no auth)] {}", safe);
//            return exec.execute(req, body);
//        };
//        RestClient.Builder restClientBuilder = RestClient.builder()
//                .requestInterceptor(logInterceptor);
//
//        // --- WebClient 로깅 필터 (stream용) ---
//        ExchangeFilterFunction webLogFilter = ExchangeFilterFunction.ofRequestProcessor(clientRequest -> {
//            var safe = new LinkedMultiValueMap<>(clientRequest.headers());
//            safe.remove(HttpHeaders.AUTHORIZATION);
//            log.info("[GMS->OpenAI via WebClient] {} {}", clientRequest.method(), clientRequest.url());
//            log.info("[Headers(no auth)] {}", safe);
//            return reactor.core.publisher.Mono.just(clientRequest);
//        });
//        WebClient.Builder webClientBuilder = WebClient.builder().filter(webLogFilter);
//
//        // --- OpenAI API (게이트웨이 경로/슬래시 정확히) ---
//        OpenAiApi api = OpenAiApi.builder()
//                .apiKey(gmsKey)                                    // 반드시 GMS_KEY!
//                .baseUrl("https://gms.ssafy.io/gmsapi/")           // 끝에 슬래시 O
//                .completionsPath("api.openai.com/v1/chat/completions") // 앞 슬래시 X
//                .embeddingsPath("api.openai.com/v1/embeddings")        // 필요 시 동일 규칙
//                .restClientBuilder(restClientBuilder)
//                .webClientBuilder(webClientBuilder)
//                .build();
//
//        // --- 옵션: User-Agent/Accept 만 추가 (Host 절대 넣지 말 것) ---
//        Map<String, String> extraHeaders = new HashMap<>();
//        extraHeaders.put("User-Agent", "curl/8.6.0");
//        extraHeaders.put("Accept", "application/json");
//
//        OpenAiChatOptions options = OpenAiChatOptions.builder()
//                .model("gpt-4o-mini")     // 필요 시 gpt-4o-mini 로 변경 가능
//                .temperature(0.2)
//                .httpHeaders(extraHeaders)
//                .build();
//
//        OpenAiChatModel model = OpenAiChatModel.builder()
//                .openAiApi(api)
//                .defaultOptions(options)
//                .build();
//
//        return ChatClient.builder(model);
//    }
//
//    @Bean
//    public ChatClient gmsChatClient(ChatClient.Builder builder) {
//        return builder.build();
//    }
//}


package com.dolijo.moring.config;

import lombok.extern.log4j.Log4j2;
import lombok.extern.slf4j.Slf4j;
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
        RestClient.Builder restClientBuilder = RestClient.builder()
                .requestInterceptor(logInterceptor);

        // --- WebClient 로깅 필터 (stream용) ---
        ExchangeFilterFunction webLogFilter = ExchangeFilterFunction.ofRequestProcessor(clientRequest -> {
            var safe = new LinkedMultiValueMap<>(clientRequest.headers());
            safe.remove(HttpHeaders.AUTHORIZATION);
            return reactor.core.publisher.Mono.just(clientRequest);
        });
        WebClient.Builder webClientBuilder = WebClient.builder().filter(webLogFilter);

        // --- OpenAI API
        OpenAiApi api = OpenAiApi.builder()
                .apiKey(gmsKey)                                    // 반드시 GMS_KEY!
                .baseUrl("https://gms.ssafy.io/gmsapi/")           // 끝에 슬래시 O
                .completionsPath("api.openai.com/v1/chat/completions") // 앞 슬래시 X
                .embeddingsPath("api.openai.com/v1/embeddings")        // 필요 시 동일 규칙
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