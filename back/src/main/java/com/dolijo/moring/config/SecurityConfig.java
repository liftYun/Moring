package com.dolijo.moring.config;

import com.dolijo.moring.security.jwt.JWTFilter;
import com.dolijo.moring.security.jwt.JWTUtil;
import com.dolijo.moring.security.jwt.LoginFilter;
import com.dolijo.moring.security.jwt.OAuth2SuccessHandler;
import com.dolijo.moring.security.service.CustomOAuth2UserService;
import com.dolijo.moring.security.service.SocialMemberService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.log4j.Log4j2;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;

import java.util.Collections;

@Configuration
@EnableWebSecurity
@Log4j2
@EnableMethodSecurity(prePostEnabled = true)
public class SecurityConfig {

    private final AuthenticationConfiguration authenticationConfiguration;
    private final JWTUtil jwtUtil;
    private final SocialMemberService socialMemberService;
    private final CustomOAuth2UserService customOAuth2UserService;
    private final OAuth2SuccessHandler oAuth2SuccessHandler;

    public SecurityConfig(
            AuthenticationConfiguration authenticationConfiguration,
            JWTUtil jwtUtil,
            SocialMemberService socialMemberService,
            CustomOAuth2UserService customOAuth2UserService,
            OAuth2SuccessHandler oAuth2SuccessHandler
    ) {
        this.authenticationConfiguration = authenticationConfiguration;
        this.jwtUtil = jwtUtil;
        this.socialMemberService = socialMemberService;
        this.customOAuth2UserService = customOAuth2UserService;
        this.oAuth2SuccessHandler = oAuth2SuccessHandler;
    }

    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration configuration) throws Exception {
        return configuration.getAuthenticationManager();
    }

    @Bean
    public BCryptPasswordEncoder bCryptPasswordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {

        // 1) CORS 설정
        http.cors(cors -> cors.configurationSource(new CorsConfigurationSource() {
            @Override
            public CorsConfiguration getCorsConfiguration(HttpServletRequest request) {
                CorsConfiguration cfg = new CorsConfiguration();
                cfg.setAllowedOrigins(Collections.singletonList("http://localhost:3000"));
                cfg.setAllowedMethods(Collections.singletonList("*"));
                cfg.setAllowCredentials(true);
                cfg.setAllowedHeaders(Collections.singletonList("*"));
                cfg.setMaxAge(3600L);
                cfg.setExposedHeaders(Collections.singletonList("Authorization"));
                return cfg;
            }
        }));

        // 2) CSRF, FormLogin, BasicAuth 비활성화
        http.csrf(csrf -> csrf.disable());
        http.formLogin(form -> form.disable());
        http.httpBasic(basic -> basic.disable());

        // 3) 경로별 인가 설정
        http.authorizeHttpRequests(auth -> auth
                // 카카오 인가코드를 받아 처리하는 엔드포인트
                // OAuth2 요청 진입점 허용
                .requestMatchers(HttpMethod.GET, "/oauth2/authorization/kakao").permitAll()
                // OAuth2 로그인 콜백 URI 허용
                .requestMatchers(HttpMethod.GET, "/login/oauth2/code/kakao").permitAll()
                .requestMatchers(HttpMethod.GET, "/api/kakao/redirect").permitAll()
                // 기존 로그인(username/password) 엔드포인트
                .requestMatchers(HttpMethod.POST, "/login").permitAll()
                // Swagger, 공용 API
                .requestMatchers("/", "/api/v1/**", "/swagger-ui/**", "/v3/api-docs/**").permitAll()
                // 토큰 보유자
                .requestMatchers("/api/v1/cache/**").authenticated()
                // 역할별 접근 제어
                .requestMatchers("/admin/**").hasRole("ADMIN")
                .requestMatchers("/user/**").hasRole("USER")
                .anyRequest().authenticated()
        );

        // 4) JWT 필터 등록 (모든 요청 앞에서 검사)
        http.addFilterBefore(new JWTFilter(jwtUtil), LoginFilter.class);

//        // 5) 기존 username/password 로그인 필터
//        http.addFilterAt(
//                new LoginFilter(authenticationManager(authenticationConfiguration), jwtUtil, refreshTokenService),
//                UsernamePasswordAuthenticationFilter.class
//        );

        // 6) OAuth2 로그인 설정 (Spring Security Client 사용 시)
        http.oauth2Login(oauth2 -> oauth2
                // 회원정보(UserInfo)를 가져올 커스텀 서비스
                .userInfoEndpoint(userInfo -> userInfo.userService(customOAuth2UserService))
                // 인증 성공 시 자체 JWT 발급
                .successHandler(oAuth2SuccessHandler)
        );

        // 7) 세션 상태를 Stateless 로 설정
        http.sessionManagement(session -> session
                .sessionCreationPolicy(SessionCreationPolicy.STATELESS)
        );

        return http.build();
    }
}
