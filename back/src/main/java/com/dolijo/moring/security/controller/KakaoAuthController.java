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
import com.dolijo.moring.security.service.JoinService;
import com.dolijo.moring.security.service.SocialMemberService;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestTemplate;

import java.io.IOException;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Map;

@RestController
@RequestMapping("/api/kakao")
public class KakaoAuthController {

    private final RestTemplate restTemplate;
    private final JoinService joinService;
    private final SocialMemberService socialMemberService;
    private final JWTUtil jwtUtil;
    private final ObjectMapper objectMapper;

    public KakaoAuthController(
            RestTemplate restTemplate,
            JoinService joinService,
            SocialMemberService socialMemberService,
            JWTUtil jwtUtil,
            ObjectMapper objectMapper
    ) {
        this.restTemplate = restTemplate;
        this.joinService = joinService;
        this.socialMemberService = socialMemberService;
        this.jwtUtil = jwtUtil;
        this.objectMapper = objectMapper;
    }

    @GetMapping("/redirect")
    public void loginViaKakao(
            @RequestHeader("Authorization") String kakaoAuth,
            @RequestHeader("Kakao-Refresh-Token") String kakaoRefreshToken,
            @RequestHeader("Kakao-Refresh-Token-ExpiresAt") String kakaoRefreshTokenExpiresAt,
            HttpServletResponse response
    ) throws IOException {
        // 1) "Bearer <kakaoAccessToken>" 검증 및 분리
        if (kakaoAuth == null || !kakaoAuth.startsWith("Bearer ")) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "Invalid Authorization header");
            return;
        }
        String kakaoToken = kakaoAuth.substring(7).trim();

        // 2) 카카오 API로 프로필 조회 (헤더에 Bearer 토큰으로 전달)
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(kakaoToken);
        HttpEntity<Void> entity = new HttpEntity<>(headers);

        ResponseEntity<Map> kakaoResp = restTemplate.exchange(
                "https://kapi.kakao.com/v2/user/me",
                HttpMethod.GET,
                new HttpEntity<>(headers),
                Map.class
        );
        Map<String, Object> kakaoProfile = kakaoResp.getBody();
        if (kakaoProfile == null) {
            response.sendError(HttpServletResponse.SC_BAD_GATEWAY, "Failed to fetch Kakao profile");
            return;
        }

        // 3) 프로필 맵에서 안전하게 필드 꺼내기
        Map<String, Object> kakaoAccount = (Map<String, Object>) kakaoProfile.get("kakao_account");
        if (kakaoAccount == null) {
            response.sendError(HttpServletResponse.SC_BAD_GATEWAY, "kakao_account missing");
            return;
        }
        String email = (String) kakaoAccount.get("email");

        Map<String, Object> profile = (Map<String, Object>) kakaoAccount.get("profile");
        String nickname = (profile != null) ? (String) profile.get("nickname") : null;

        if (email == null && nickname == null) {
            response.sendError(HttpServletResponse.SC_BAD_GATEWAY, "Required user info missing");
            return;
        }

        // 4) 회원 가입 또는 조회
        Member member = joinService.registerKakaoUserIfNotExist(email, nickname);
        // 4) 헤더로 넘어온 만료 시각 (RFC-1123 형식) 파싱
        OffsetDateTime odt = OffsetDateTime.parse(
                kakaoRefreshTokenExpiresAt,
                DateTimeFormatter.RFC_1123_DATE_TIME
        );
        // 서버 로컬 시간대 기준 LocalDateTime 으로 변환
        LocalDateTime kakaoRefreshExpiresAt = odt
                .atZoneSameInstant(ZoneId.systemDefault())
                .toLocalDateTime();

        socialMemberService.saveToken(
                member.getId(),
                SocialType.KAKAO,
                kakaoRefreshToken,
                kakaoRefreshExpiresAt
        );

        // 5) 자체 JWT 토큰 발급
        String ourAccess  = jwtUtil.generateAccessToken(member);
        String ourRefresh = jwtUtil.generateRefreshToken(member);

        // 6) 응답 헤더에 Access Token, Set-Cookie, JSON body
        response.setHeader(HttpHeaders.AUTHORIZATION, "Bearer " + ourAccess);
        String cookie = String.format(
                "refreshToken=%s; Path=/; HttpOnly; SameSite=None; Max-Age=%d",
                ourRefresh,
                jwtUtil.getRefreshExpiredMs() / 1000
        );
        response.addHeader(HttpHeaders.SET_COOKIE, cookie);

        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        objectMapper.writeValue(response.getWriter(), Map.of("accessToken", ourAccess));
    }
}
