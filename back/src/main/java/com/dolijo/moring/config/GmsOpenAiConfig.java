package com.dolijo.moring.config;//package com.dolijo.moring.config;
//
//import lombok.extern.log4j.Log4j2;
//import org.apache.hc.client5.http.config.RequestConfig;
//import org.apache.hc.client5.http.cookie.StandardCookieSpec;
//import org.apache.hc.client5.http.impl.classic.CloseableHttpClient;
//import org.apache.hc.client5.http.impl.classic.HttpClients;
//import org.springframework.ai.chat.client.ChatClient;
//import org.springframework.ai.embedding.EmbeddingModel;
//import org.springframework.ai.openai.OpenAiChatModel;
//import org.springframework.ai.openai.OpenAiChatOptions;
//import org.springframework.ai.openai.OpenAiEmbeddingModel;
//import org.springframework.ai.openai.OpenAiEmbeddingOptions;
//import org.springframework.ai.openai.api.OpenAiApi;
//import org.springframework.beans.factory.annotation.Value;
//import org.springframework.context.annotation.Bean;
//import org.springframework.context.annotation.Configuration;
//import org.springframework.context.annotation.Primary;
//import org.springframework.http.HttpHeaders;
//import org.springframework.http.client.ClientHttpRequestInterceptor;
//import org.springframework.http.client.HttpComponentsClientHttpRequestFactory;
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
//    private static final String CATEGORY = "pdf/Moring_Traffic_Safety_Guide_2024.pdf";
//
//
//    @Bean
//    @Primary
//    public ChatClient.Builder gmsChatClientBuilder(
//            @Value("${gms.gateway.key}") String gmsKey
//    ) {
//        ClientHttpRequestInterceptor logInterceptor = (req, body, exec) -> {
//            URI uri = req.getURI();
//            HttpHeaders safe = new HttpHeaders();
//            safe.putAll(req.getHeaders());
//            if (safe.containsKey(HttpHeaders.AUTHORIZATION)) {
//                safe.set(HttpHeaders.AUTHORIZATION, "Bearer ***");
//            }
//            return exec.execute(req, body);
//        };
//        // RestClient 빌더 생성 (위의 로깅 인터셉터 적용)
//        RestClient.Builder restClientBuilder = RestClient.builder()
//                .requestInterceptor(logInterceptor);
//
//        // --- WebClient 로깅 필터 (stream용) ---
//        ExchangeFilterFunction webLogFilter = ExchangeFilterFunction.ofRequestProcessor(clientRequest -> {
//            var safe = new LinkedMultiValueMap<>(clientRequest.headers());
//            safe.remove(HttpHeaders.AUTHORIZATION);
//            return reactor.core.publisher.Mono.just(clientRequest);
//        });
//        WebClient.Builder webClientBuilder = WebClient.builder().filter(webLogFilter);
//
//        // OpenAiApi 객체 생성
//        OpenAiApi api = OpenAiApi.builder()
//                .apiKey(gmsKey)
//                .baseUrl("https://gms.ssafy.io/gmsapi/")
//                .completionsPath("api.openai.com/v1/chat/completions")
//                .embeddingsPath("api.openai.com/v1/embeddings")
//                .restClientBuilder(restClientBuilder)
//                .webClientBuilder(webClientBuilder)
//                .build();
//
//        // 옵션: User-Agent/Accept 만 추가 (Host 넣으면 에러남)
//        Map<String, String> extraHeaders = new HashMap<>();
//        extraHeaders.put("User-Agent", "curl/8.6.0");
//        extraHeaders.put("Accept", "application/json");
//
//        OpenAiChatOptions options = OpenAiChatOptions.builder()
//                .model("gpt-4o-mini")
//                .temperature(0.1)
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
//
////    @Bean
////    public EmbeddingModel embeddingModel(@Value("${gms.gateway.key}") String gmsKey) {
////        OpenAiApi openAiApi = OpenAiApi.builder()
////                .apiKey(gmsKey)
////                .baseUrl("https://gms.ssafy.io/gmsapi/")
////                .embeddingsPath("api.openai.com/v1/embeddings")
////                .build();
////
////        // MetadataMode.EMBED와 모델명 명시
////        return new OpenAiEmbeddingModel(
////                openAiApi,
////                org.springframework.ai.document.MetadataMode.EMBED,
////                OpenAiEmbeddingOptions.builder()
////                        .model("text-embedding-3-small") // 원하는 임베딩 모델
////                        .build());
////    }
//
//
//    @Bean
//    public EmbeddingModel embeddingModel(
//            @Value("${gms.gateway.key}") String gmsKey) {
//
//        // Chat에서 쓰던 것 그대로 재사용(로깅 필터/인터셉터 포함)
//        ClientHttpRequestInterceptor logInterceptor = (req, body, exec) -> {
//            HttpHeaders safe = new HttpHeaders();
//            safe.putAll(req.getHeaders());
//            if (safe.containsKey(HttpHeaders.AUTHORIZATION)) {
//                safe.set(HttpHeaders.AUTHORIZATION, "Bearer ***");
//            }
//            return exec.execute(req, body);
//        };
//        RestClient.Builder restClientBuilder = RestClient.builder()
//                .requestInterceptor(logInterceptor);
//
//        ExchangeFilterFunction webLogFilter = ExchangeFilterFunction.ofRequestProcessor(clientRequest -> {
//            var safe = new org.springframework.util.LinkedMultiValueMap<>(clientRequest.headers());
//            safe.remove(HttpHeaders.AUTHORIZATION);
//            return reactor.core.publisher.Mono.just(clientRequest);
//        });
//        WebClient.Builder webClientBuilder = WebClient.builder().filter(webLogFilter);
//
//        OpenAiApi openAiApi = OpenAiApi.builder()
//                .apiKey(gmsKey)
//                .baseUrl("https://gms.ssafy.io/gmsapi/")
//                .embeddingsPath("api.openai.com/v1/embeddings")
//                .restClientBuilder(restClientBuilder)
//                .webClientBuilder(webClientBuilder)
//                .build();
//
//        // 모델명 명시
//        return new OpenAiEmbeddingModel(
//                openAiApi,
//                org.springframework.ai.document.MetadataMode.EMBED,
//                OpenAiEmbeddingOptions.builder()
//                        .model("text-embedding-3-small")
//                        .build()
//        );
//    }
//
//    @Bean
//    public RestClient.Builder openAiRestClientBuilder() {
//        RequestConfig requestConfig = RequestConfig.custom()
//                .setCookieSpec(StandardCookieSpec.IGNORE)   // 쿠키 무시
//                .build();
//
//        CloseableHttpClient httpClient = HttpClients.custom()
//                .setDefaultRequestConfig(requestConfig)
//                .build();
//
//        HttpComponentsClientHttpRequestFactory rf = new HttpComponentsClientHttpRequestFactory(httpClient);
//
//        return RestClient.builder().requestFactory(rf);
//    }
//
//}


import lombok.extern.log4j.Log4j2;
import org.apache.hc.client5.http.config.RequestConfig;
import org.apache.hc.client5.http.cookie.StandardCookieSpec;
import org.apache.hc.client5.http.impl.classic.CloseableHttpClient;
import org.apache.hc.client5.http.impl.classic.HttpClients;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.embedding.EmbeddingModel;
import org.springframework.ai.openai.OpenAiChatModel;
import org.springframework.ai.openai.OpenAiChatOptions;
import org.springframework.ai.openai.OpenAiEmbeddingModel;
import org.springframework.ai.openai.OpenAiEmbeddingOptions;
import org.springframework.ai.openai.api.OpenAiApi;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.http.HttpHeaders;
import org.springframework.http.client.ClientHttpRequestInterceptor;
import org.springframework.http.client.HttpComponentsClientHttpRequestFactory;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.reactive.function.client.ExchangeFilterFunction;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.HashMap;
import java.util.Map;

@Log4j2
@Configuration
public class GmsOpenAiConfig {

    /**
     * 쿠키 무시(IGNORE) 정책이 설정된 RestClient.Builder 빈
     * - 반드시 아래 gmsChatClientBuilder/embeddingModel 에서 주입받아 사용
     */
    @Bean
    public RestClient.Builder openAiRestClientBuilder() {
        RequestConfig requestConfig = RequestConfig.custom()
                .setCookieSpec(StandardCookieSpec.IGNORE) // ★ 쿠키 무시
                .build();

        CloseableHttpClient httpClient = HttpClients.custom()
                .setDefaultRequestConfig(requestConfig)
                .build();

        HttpComponentsClientHttpRequestFactory rf = new HttpComponentsClientHttpRequestFactory(httpClient);
        return RestClient.builder().requestFactory(rf);
    }

    /**
     * ChatClient.Builder (GMS 프록시 경유 OpenAI)
     */
    @Bean
    @Primary
    public ChatClient.Builder gmsChatClientBuilder(
            @Value("${gms.gateway.key}") String gmsKey,
            RestClient.Builder openAiRestClientBuilder // ★ 주입
    ) {
        // 요청 로깅(Authorization 마스킹)
        ClientHttpRequestInterceptor logInterceptor = (req, body, exec) -> {
            HttpHeaders safe = new HttpHeaders();
            safe.putAll(req.getHeaders());
            if (safe.containsKey(HttpHeaders.AUTHORIZATION)) {
                safe.set(HttpHeaders.AUTHORIZATION, "Bearer ***");
            }
            return exec.execute(req, body);
        };

        // ★ 새로 만들지 말고, 주입된 빌더에 인터셉터만 추가
        RestClient.Builder restClientBuilder = openAiRestClientBuilder
                .requestInterceptor(logInterceptor);

        // WebClient 로깅 필터(Authorization 제거)
        ExchangeFilterFunction webLogFilter = ExchangeFilterFunction.ofRequestProcessor(clientRequest -> {
            var safe = new LinkedMultiValueMap<>(clientRequest.headers());
            safe.remove(HttpHeaders.AUTHORIZATION);
            return reactor.core.publisher.Mono.just(clientRequest);
        });
        WebClient.Builder webClientBuilder = WebClient.builder().filter(webLogFilter);

        // OpenAI API (프록시 + 업스트림 경로 설정)
        OpenAiApi api = OpenAiApi.builder()
                .apiKey(gmsKey)
                .baseUrl("https://gms.ssafy.io/gmsapi/")
                .completionsPath("api.openai.com/v1/chat/completions")
                .embeddingsPath("api.openai.com/v1/embeddings")
                .restClientBuilder(restClientBuilder)   // ★ 쿠키 IGNORE 반영됨
                .webClientBuilder(webClientBuilder)
                .build();

        // 기본 옵션
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

    /**
     * 편의용 ChatClient (필수는 아님)
     */
    @Bean
    public ChatClient gmsChatClient(ChatClient.Builder builder) {
        return builder.build();
    }

    /**
     * EmbeddingModel (GMS 프록시 경유 OpenAI)
     * - Chat과 동일한 RestClient/WebClient 설정 재사용
     */
    @Bean
    public EmbeddingModel embeddingModel(
            @Value("${gms.gateway.key}") String gmsKey,
            RestClient.Builder openAiRestClientBuilder // ★ 주입
    ) {
        ClientHttpRequestInterceptor logInterceptor = (req, body, exec) -> {
            HttpHeaders safe = new HttpHeaders();
            safe.putAll(req.getHeaders());
            if (safe.containsKey(HttpHeaders.AUTHORIZATION)) {
                safe.set(HttpHeaders.AUTHORIZATION, "Bearer ***");
            }
            return exec.execute(req, body);
        };

        RestClient.Builder restClientBuilder = openAiRestClientBuilder
                .requestInterceptor(logInterceptor);     // ★ 쿠키 IGNORE 반영

        ExchangeFilterFunction webLogFilter = ExchangeFilterFunction.ofRequestProcessor(clientRequest -> {
            var safe = new org.springframework.util.LinkedMultiValueMap<>(clientRequest.headers());
            safe.remove(HttpHeaders.AUTHORIZATION);
            return reactor.core.publisher.Mono.just(clientRequest);
        });
        WebClient.Builder webClientBuilder = WebClient.builder().filter(webLogFilter);

        OpenAiApi openAiApi = OpenAiApi.builder()
                .apiKey(gmsKey)
                .baseUrl("https://gms.ssafy.io/gmsapi/")
                .embeddingsPath("api.openai.com/v1/embeddings")
                .restClientBuilder(restClientBuilder)     // ★ 쿠키 IGNORE 반영
                .webClientBuilder(webClientBuilder)
                .build();

        return new OpenAiEmbeddingModel(
                openAiApi,
                org.springframework.ai.document.MetadataMode.EMBED,
                OpenAiEmbeddingOptions.builder()
                        .model("text-embedding-3-small")
                        .build()
        );
    }
}