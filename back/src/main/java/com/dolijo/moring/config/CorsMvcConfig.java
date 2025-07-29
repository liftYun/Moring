package com.dolijo.moring.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

// CORS 오류 해결 (2)
@Configuration
public class CorsMvcConfig implements WebMvcConfigurer {

    @Override
    public void addCorsMappings(CorsRegistry corsRegistry) {

        corsRegistry.addMapping("/**")
                .allowedOrigins("http://localhost:3000")
                .allowedMethods("*")                      // GET,POST,PUT,DELETE,OPTIONS…
                .allowedHeaders("*")                      // 모든 헤더
                .exposedHeaders("Authorization")          // 클라이언트에서 읽을 헤더
                .allowCredentials(true)                   // 쿠키 전달 허용 → 응답에 Access-Control-Allow-Credentials: true
                .maxAge(3600);
    }
}
