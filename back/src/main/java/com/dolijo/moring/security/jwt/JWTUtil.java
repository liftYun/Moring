package com.dolijo.moring.security.jwt;

import com.dolijo.moring.member.entity.Member;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.Jwts;
import lombok.Getter;
import lombok.extern.log4j.Log4j2;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.util.Date;

@Component
@Log4j2
public class JWTUtil {

    private final SecretKey secretKey;

    /** Access Token 만료시간(ms) 반환 */
    @Getter @Value("${jwt.access.expired-ms}")
    private long accessExpiredMs;

    /** Refresh Token 만료시간(ms) 반환 */
    @Getter @Value("${jwt.refresh.expired-ms}")
    private long refreshExpiredMs;

    public JWTUtil(@Value("${spring.jwt.secret}") String secret) {
        log.info("JWT secret loaded");
        this.secretKey = new SecretKeySpec(
                secret.getBytes(StandardCharsets.UTF_8),
                Jwts.SIG.HS256.key().build().getAlgorithm()
        );
    }

    /** 토큰에서 UUID 추출 */
    public String getUserUuid(String token) {
        return parseClaims(token).get("uuid", String.class);
    }

    /** 토큰에서 이메일 추출 (claim key: "userEmail") */
    public String getUserEmail(String token) {
        return parseClaims(token).get("userEmail", String.class);
    }

    /** 토큰에서 닉네임 추출 */
    public String getUserNickname(String token) {
        return parseClaims(token).get("nickname", String.class);
    }

    /** 토큰 만료 여부 확인 */
    public Boolean isExpired(String token) {
        try {
            return parseClaims(token).getExpiration().before(new Date());
        } catch (ExpiredJwtException e) {
            log.warn("Expired JWT token", e);
            return true;
        }
    }

    /** AccessToken 생성 (직접 호출용) */
    public String createAccessToken(String uuid, String nickname) {
        return Jwts.builder()
                .claim("uuid", uuid)
//                .claim("userEmail", userEmail)
                .claim("nickname", nickname)
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + accessExpiredMs))
                .signWith(secretKey)
                .compact();
    }

    /** RefreshToken 생성 (직접 호출용) */
    public String createRefreshToken(String uuid) {
        return Jwts.builder()
                .claim("uuid", uuid)
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + refreshExpiredMs))
                .signWith(secretKey)
                .compact();
    }

    /** OAuth2 흐름 편의를 위한 오버로드 */
    public String generateAccessToken(Member member) {
        return createAccessToken(
                member.getUuid(),
//                member.getEmail(),
                member.getNickName()
        );
    }

    public String generateRefreshToken(Member member) {
        return createRefreshToken(member.getUuid());
    }

    /** 서명 검증 후 Claims 반환 */
    public Claims parseClaims(String token) {
        return Jwts.parser()
                .verifyWith(secretKey)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }
}
