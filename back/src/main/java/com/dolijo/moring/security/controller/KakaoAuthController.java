//package org.example.oauthtest.security.controller;
//
//import com.fasterxml.jackson.databind.ObjectMapper;
//import jakarta.servlet.http.HttpServletResponse;
//import org.example.oauthtest.security.entity.SocialType;
//import org.example.oauthtest.security.entity.UserEntity;
//import org.example.oauthtest.security.service.JoinService;
//import org.example.oauthtest.security.service.RefreshTokenService;
//import org.example.oauthtest.security.jwt.JWTUtil;
//import org.example.oauthtest.security.jwt.KakaoOAuth2Properties;
//import org.springframework.http.HttpHeaders;
//import org.springframework.http.MediaType;
//import org.springframework.http.ResponseEntity;
//import org.springframework.web.bind.annotation.GetMapping;
//import org.springframework.web.bind.annotation.RequestHeader;
//import org.springframework.web.bind.annotation.RequestMapping;
//import org.springframework.web.bind.annotation.RestController;
//import org.springframework.web.client.RestTemplate;
//
//import java.util.Map;
//
//@RestController
//@RequestMapping("/api/kakao")
//public class KakaoAuthController {
//
//    private final RestTemplate restTemplate;
//    private final KakaoOAuth2Properties props;
//    private final JoinService joinService;
//    private final RefreshTokenService refreshTokenService;
//    private final JWTUtil jwtUtil;
//    private final ObjectMapper objectMapper;
//
//    public KakaoAuthController(
//            RestTemplate restTemplate,
//            KakaoOAuth2Properties props,
//            JoinService joinService,
//            RefreshTokenService refreshTokenService,
//            JWTUtil jwtUtil,
//            ObjectMapper objectMapper
//    ) {
//        this.restTemplate = restTemplate;
//        this.props = props;
//        this.joinService = joinService;
//        this.refreshTokenService = refreshTokenService;
//        this.jwtUtil = jwtUtil;
//        this.objectMapper = objectMapper;
//    }
//
//    @GetMapping("/redirect")
//    public void loginViaKakao(
//            @RequestHeader("Authorization") String kakaoAuth,
//            HttpServletResponse response
//    ) throws Exception {
//        // 1) "Bearer <kakaoAccessToken>" → 토큰 문자열만 분리
//        String kakaoToken = kakaoAuth.replaceFirst("Bearer ", "");
//
//        // 2) 카카오 API로 프로필 조회
//        Map<String,Object> kakaoProfile = restTemplate.getForObject(
//            "https://kapi.kakao.com/v2/user/me?secure_resource=true&property_keys=[\"kakao_account.email\",\"properties.nickname\"]&access_token=" + kakaoToken,
//            Map.class);
//        Map<String,Object> account = (Map) kakaoProfile.get("kakao_account");
//        String email = (String) account.get("email");
//        String nickname = (String)((Map)account.get("profile")).get("nickname");
//
//        // 3) 사용자 가입 또는 조회
//        UserEntity user = joinService.registerKakaoUserIfNotExist(email, nickname);
//
//        // 4) 자체 JWT 발급
//        String ourAccess  = jwtUtil.generateAccessToken(user);
//        String ourRefresh = jwtUtil.generateRefreshToken(user);
//
//        // 5) DB에 리프레시 토큰 저장 (소셜 타입 포함)
//        refreshTokenService.saveToken(user.getUuid(), SocialType.KAKAO, ourRefresh);
//
//        // 6) 응답 헤더 + 쿠키 + JSON 바디
//        response.setHeader(HttpHeaders.AUTHORIZATION, "Bearer " + ourAccess);
//        String cookie = String.format(
//            "refreshToken=%s; Path=/; HttpOnly; SameSite=None; Max-Age=%d",
//            ourRefresh,
//            jwtUtil.getRefreshExpiredMs() / 1000
//        );
//        response.addHeader(HttpHeaders.SET_COOKIE, cookie);
//
//        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
//        response.getWriter().write(
//            objectMapper.writeValueAsString(Map.of("accessToken", ourAccess))
//        );
//    }
//}


package com.dolijo.moring.security.controller;
import com.dolijo.moring.member.entity.Member;
import com.dolijo.moring.member.valueobject.SocialType;
import com.dolijo.moring.security.jwt.JWTUtil;
import com.dolijo.moring.security.jwt.KakaoOAuth2Properties;
import com.dolijo.moring.security.service.JoinService;
import com.dolijo.moring.security.service.SocialMemberService;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletResponse;
import lombok.Value;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.*;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.io.IOException;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Map;

import static com.dolijo.moring.member.valueobject.SocialType.KAKAO;

@RestController
@RequestMapping("/api/kakao")
@Tag(name = "회원", description = "회원 관련 API")
public class KakaoAuthController {

    private final RestTemplate restTemplate;
    private final JoinService joinService;
    private final SocialMemberService socialMemberService;
    private final JWTUtil jwtUtil;
    private final ObjectMapper objectMapper;
    private final KakaoOAuth2Properties props;

    private final KakaoOAuth2Properties kakaoProperties;

    public KakaoAuthController(
            RestTemplate restTemplate,
            JoinService joinService,
            SocialMemberService socialMemberService,
            JWTUtil jwtUtil,
            ObjectMapper objectMapper, KakaoOAuth2Properties props, KakaoOAuth2Properties kakaoProperties
    ) {
        this.restTemplate = restTemplate;
        this.joinService = joinService;
        this.socialMemberService = socialMemberService;
        this.jwtUtil = jwtUtil;
        this.objectMapper = objectMapper;
        this.props = props;
        this.kakaoProperties = kakaoProperties;
    }

    @GetMapping("/redirect")
    @Operation(summary = "OAuth Redirect",   description = """
        OAuth로 로그인을 진행한 유저를 등록합니다

        - OAuth로 로그인 한 유저가 기존 유저인지 신규 유저인지 확인합니다.
        - 신규일 시 로그인 정보를 이용하여 등록을 진행합니다.
        - 기존 회원이거나 등록이 완료된 회원의 경우 카카오 토큰을 저장합니다.
        - 클라이언트에게는 자체 발행한 JWT를 전달합니다.
        """)
    public void loginViaKakao(
            @RequestParam("code") String code,
            HttpServletResponse response
    ) throws IOException {
        System.out.println("redirect URL : "+kakaoProperties.getRedirectUri());
        System.out.println("Kakao Code : "+ code);
        // 1) code → 카카오 토큰 교환
        MultiValueMap<String, String> params = new LinkedMultiValueMap<>();
        params.add("grant_type", "authorization_code");
        params.add("client_id", kakaoProperties.getClientId());
        params.add("client_secret", kakaoProperties.getClientSecret());
        params.add("redirect_uri", kakaoProperties.getRedirectUri());
        params.add("code", code);

        HttpHeaders tokenHeaders = new HttpHeaders();
        tokenHeaders.setContentType(MediaType.APPLICATION_FORM_URLENCODED);
        HttpEntity<MultiValueMap<String,String>> tokenRequest =
                new HttpEntity<>(params, tokenHeaders);

        ResponseEntity<Map> tokenResp = restTemplate.postForEntity(
                "https://kauth.kakao.com/oauth/token",
                tokenRequest,
                Map.class
        );
        if (!tokenResp.getStatusCode().is2xxSuccessful() || tokenResp.getBody() == null) {
            response.sendError(HttpServletResponse.SC_BAD_GATEWAY, "Failed to exchange Kakao token");
            return;
        }

        Map<String, Object> tokenBody = tokenResp.getBody();
        String kakaoAccessToken  = (String) tokenBody.get("access_token");
        String kakaoRefreshToken = (String) tokenBody.get("refresh_token");
        // refresh_expires_in: 초 단위
        Integer refreshExpiresIn = (Integer) tokenBody.get("refresh_token_expires_in");

        // 2) 카카오 프로필 조회
        HttpHeaders profileHeaders = new HttpHeaders();
        profileHeaders.setBearerAuth(kakaoAccessToken);
        ResponseEntity<Map> profileResp = restTemplate.exchange(
                "https://kapi.kakao.com/v2/user/me",
                HttpMethod.GET,
                new HttpEntity<>(profileHeaders),
                Map.class
        );
        Map<String, Object> kakaoProfile = profileResp.getBody();
        if (kakaoProfile == null) {
            response.sendError(HttpServletResponse.SC_BAD_GATEWAY, "Failed to fetch Kakao profile");
            return;
        }

        Map<String, Object> kakaoAccount = (Map<String, Object>) kakaoProfile.get("kakao_account");
        String email    = kakaoAccount != null ? (String) kakaoAccount.get("email") : null;
        Map<String, Object> profile = kakaoAccount != null
                ? (Map<String, Object>) kakaoAccount.get("profile")
                : null;
        String nickname = profile != null ? (String) profile.get("nickname") : null;

        // 3) 유저 등록 또는 조회
        Member member = joinService.registerKakaoUserIfNotExist(email, nickname);

        // 4) 카카오 refresh 토큰 만료시간 계산
        LocalDateTime kakaoRefreshExpiresAt = LocalDateTime.now()
                .plusSeconds(refreshExpiresIn != null ? refreshExpiresIn : 0L);

        socialMemberService.saveToken(
                member.getUuid(),
                KAKAO,
                kakaoRefreshToken,
                kakaoRefreshExpiresAt
        );

        // 5) 자체 JWT 발급
        String ourAccess  = jwtUtil.generateAccessToken(member);
        String ourRefresh = jwtUtil.generateRefreshToken(member, KAKAO);

        // 6) 응답에 JWT 전달
        // Access-Token 헤더
        response.setHeader(HttpHeaders.AUTHORIZATION, "Bearer " + ourAccess);
        // HttpOnly 쿠키에 refreshToken
        String cookie = String.format(
                "refreshToken=%s; Path=/; HttpOnly; SameSite=None; Max-Age=%d",
                ourRefresh,
                jwtUtil.getRefreshExpiredMs() / 1000
        );
        response.addHeader(HttpHeaders.SET_COOKIE, cookie);

        // JSON body 에도 accessToken 포함
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        objectMapper.writeValue(
                response.getWriter(),
                Map.of("accessToken", ourAccess)
        );
    }

    /**
     * 1) 클라이언트가 이 URL 로 들어오면
     * 2) 카카오 인가 페이지로 Redirect (response_type=code)
     */
    @GetMapping("/login")
    public void kakaoLogin(
            @RequestParam("redirect_uri") String clientRedirectUri,
            HttpServletResponse response,
            KakaoOAuth2Properties props
    ) throws IOException {
        System.out.println("kakao login API 접근");
        String authorizeUrl = UriComponentsBuilder
                .fromHttpUrl("https://kauth.kakao.com/oauth/authorize")
                .queryParam("response_type", "code")
                .queryParam("client_id", props.getClientId())
                .queryParam("client_secret", props.getClientSecret())
                .queryParam("redirect_uri", clientRedirectUri)
                .build()
                .toUriString();

        response.sendRedirect(authorizeUrl);
    }
}
