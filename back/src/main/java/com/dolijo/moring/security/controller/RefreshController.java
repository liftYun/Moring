package com.dolijo.moring.security.controller;

import com.dolijo.moring.member.valueobject.SocialType;
import com.dolijo.moring.security.dto.out.CustomUserDetails;
import com.dolijo.moring.security.jwt.JWTUtil;
import com.dolijo.moring.security.service.CustomUserDetailsService;
import com.dolijo.moring.security.service.RefreshTokenService;
import com.dolijo.moring.security.vo.out.TokenResponseVo;
import io.jsonwebtoken.Claims;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.log4j.Log4j2;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CookieValue;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
@Log4j2
public class RefreshController {

    private final JWTUtil jwtUtil;
    private final RefreshTokenService refreshTokenService;
    private final CustomUserDetailsService customUserDetailsService;

    public RefreshController(
            JWTUtil jwtUtil,
            RefreshTokenService refreshTokenService,
            CustomUserDetailsService customUserDetailsService
    ) {
        this.jwtUtil = jwtUtil;
        this.refreshTokenService = refreshTokenService;
        this.customUserDetailsService = customUserDetailsService;
    }

    @PostMapping("/refresh")
    public ResponseEntity<TokenResponseVo> refreshToken(
            @CookieValue(name = "refreshToken") String refreshToken,
            HttpServletResponse response
    ) {
        log.info("Refresh token request received");

        // 1) 서명 + 만료 검사
        Claims claims = jwtUtil.parseClaims(refreshToken);
        String uuid = claims.get("uuid", String.class);
        SocialType type = SocialType.valueOf(claims.get("type", String.class));

        // 2) DB 저장 토큰 검증
        if (!refreshTokenService.isValid(uuid, refreshToken, type)) {
            refreshTokenService.deleteToken(uuid);
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        // 3) UserDetails 재조회
        CustomUserDetails userDetails = customUserDetailsService.loadUserByUuid(uuid);

        // 4) 새 토큰 생성
        String newRefreshToken = jwtUtil.createRefreshToken(uuid);
        String newAccessToken = jwtUtil.createAccessToken(
                uuid,
                userDetails.getUserEmail(),
                userDetails.getUserNickname()
        );


        // 5) DB에 새 리프레시 토큰 저장
        refreshTokenService.saveToken(uuid, type, newRefreshToken);

        // 6) HTTP-only 쿠키로 새 리프레시 토큰 설정
        Cookie cookie = new Cookie("refreshToken", newRefreshToken);
        cookie.setHttpOnly(true);
        cookie.setPath("/");
        cookie.setMaxAge((int) (jwtUtil.getRefreshExpiredMs() / 1000));
        // 필요 시 secure/same-site 설정
        // cookie.setSecure(true);
        // cookie.setComment("SameSite=None");
        response.addCookie(cookie);

        // 7) 응답 헤더 및 바디에 액세스/리프레시 토큰 전달
        TokenResponseVo body = new TokenResponseVo(newAccessToken, newRefreshToken);
        return ResponseEntity.ok()
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + newAccessToken)
                .body(body);
    }
}