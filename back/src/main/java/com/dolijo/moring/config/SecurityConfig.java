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
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.oauth2.client.registration.ClientRegistrationRepository;
import org.springframework.security.oauth2.client.web.DefaultOAuth2AuthorizationRequestResolver;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.HttpStatusEntryPoint;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;

import java.util.Collections;

@Configuration
@EnableWebSecurity
@Log4j2
@EnableMethodSecurity(prePostEnabled = true)
public class SecurityConfig {

    private final ClientRegistrationRepository clientRegistrationRepository;
    private final AuthenticationConfiguration authenticationConfiguration;
    private final JWTUtil jwtUtil;
    private final SocialMemberService socialMemberService;
    private final CustomOAuth2UserService customOAuth2UserService;
    private final OAuth2SuccessHandler oAuth2SuccessHandler;

    public SecurityConfig(
            ClientRegistrationRepository clientRegistrationRepository, AuthenticationConfiguration authenticationConfiguration,
            JWTUtil jwtUtil,
            SocialMemberService socialMemberService,
            CustomOAuth2UserService customOAuth2UserService,
            OAuth2SuccessHandler oAuth2SuccessHandler
    ) {
        this.clientRegistrationRepository = clientRegistrationRepository;
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
                cfg.setAllowedOrigins(Collections.singletonList("https://i13e101.p.ssafy.io/"));
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
                        // OAuth2 로그인 콜백 URI 허용
                        .requestMatchers(HttpMethod.GET,
                                "/oauth2/authorization/kakao",
                                "/login/oauth2/code/kakao",
                                "/api/kakao/redirect",
                                "/api/kakao/login",
                                "/api/kakao/login",
                                "/api/v1/auth/login/test",
                                "/api/v1/health/**").permitAll()
                        .requestMatchers(HttpMethod.POST,
                                "/api/v1/auth/refresh",
                                "/api/v1/auth/logout/rToken").permitAll()
                        // Swagger, 공용 API
                        .requestMatchers( "/swagger-ui/**", "/v3/api-docs/**").permitAll()
                        // 토큰 보유자
                        .requestMatchers("/api/v1/**").authenticated()
                        // 역할별 접근 제어
//                .requestMatchers("/admin/**").hasRole("ADMIN")
//                .requestMatchers("/user/**").hasRole("USER")
                        .anyRequest().authenticated()
        );
        // 인증 실패 시 리다이렉트 대신 401 응답만
        http.exceptionHandling(ex -> ex
                .authenticationEntryPoint(new HttpStatusEntryPoint(HttpStatus.UNAUTHORIZED))
        );

        // 4) JWT 필터 등록 (모든 요청 앞에서 검사)
//        http.addFilterBefore(new JWTFilter(jwtUtil), LoginFilter.class);
        http.addFilterBefore(new JWTFilter(jwtUtil), UsernamePasswordAuthenticationFilter.class);

//        // 5) 기존 username/password 로그인 필터
        http.addFilterAt(
                new LoginFilter(authenticationManager(authenticationConfiguration), jwtUtil, socialMemberService),
                UsernamePasswordAuthenticationFilter.class
        );

        // 6) OAuth2 로그인 설정 (Spring Security Client 사용 시)
        http.oauth2Login(oauth2 -> oauth2
                .authorizationEndpoint(endpoint ->
                        endpoint.authorizationRequestResolver(
                                new DefaultOAuth2AuthorizationRequestResolver(
                                        clientRegistrationRepository,
                                        "/oauth2/authorization"
                                )
                        )
                )
                .redirectionEndpoint(redir ->
                        redir.baseUri("/login/oauth2/code/*")
                )
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
