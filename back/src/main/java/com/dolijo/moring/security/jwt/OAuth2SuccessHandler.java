package com.dolijo.moring.security.jwt;

import com.dolijo.moring.member.entity.Member;
import com.dolijo.moring.member.valueobject.SocialType;
import com.dolijo.moring.security.service.JoinService;
import com.dolijo.moring.security.service.RefreshTokenService;
import com.dolijo.moring.security.vo.out.TokenResponseVo;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.http.*;
import org.springframework.security.core.Authentication;
import org.springframework.security.web.authentication.AuthenticationSuccessHandler;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestTemplate;

import java.io.IOException;
import java.util.Map;

/**
 n * OAuth2 로그인 성공 시 카카오에서 받은 사용자 정보를 기반으로 회원가입/조회 후 JWT 발급 및 응답 처리
 */
@Component
public class OAuth2SuccessHandler implements AuthenticationSuccessHandler {

    private final JWTUtil jwtUtil;
    private final RefreshTokenService refreshTokenService;
    private final JoinService joinService;
    private final RestTemplate restTemplate;      // RestTemplate 혹은 WebClient
    private final String kakaoClientId;           // application.yml 에서 주입
    private final String kakaoRedirectUri;

    public OAuth2SuccessHandler(
            JWTUtil jwtUtil,
            RefreshTokenService refreshTokenService,
            JoinService joinService,
            RestTemplateBuilder restTemplateBuilder,
            KakaoOAuth2Properties props
//            @Value("${spring.security.oauth2.client.registration.kakao.clientId}") String kakaoClientId,
//            @Value("${spring.security.oauth2.client.registration.kakao.redirectUri}") String kakaoRedirectUri
    ) {
        this.jwtUtil  = jwtUtil;
        this.refreshTokenService = refreshTokenService;
        this.joinService = joinService;
        this.restTemplate = restTemplateBuilder.build();
//        this.kakaoClientId = kakaoClientId;
//        this.kakaoRedirectUri = kakaoRedirectUri;
        this.kakaoClientId  = props.getClientId();
        this.kakaoRedirectUri = props.getRedirectUri();

    }

    @Override
    public void onAuthenticationSuccess(
            HttpServletRequest request,
            HttpServletResponse response,
            Authentication authentication
    ) throws IOException {

        // 1) 인가 코드 꺼내기
        String authorizationCode = request.getParameter("code");

        // 2) 카카오 토큰 엔드포인트에 POST → 카카오 액세스/리프레시 토큰 교환
        MultiValueMap<String,String> form = new LinkedMultiValueMap<>();
        form.add("grant_type",   "authorization_code");
        form.add("client_id",    kakaoClientId);
        form.add("redirect_uri", kakaoRedirectUri);
        form.add("code",         authorizationCode);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);

        HttpEntity<MultiValueMap<String,String>> tokenRequest =
                new HttpEntity<>(form, headers);

        // 카카오 토큰 응답을 Map 으로 받되, 실제로는 DTO 를 만들어 쓰셔도 좋습니다.
        ResponseEntity<Map> tokenResponse = restTemplate.exchange(
                "https://kauth.kakao.com/oauth/token",
                HttpMethod.POST,
                tokenRequest,
                Map.class
        );

        Map<String,Object> kakaoToken = tokenResponse.getBody();
        String kakaoAccessToken  = (String) kakaoToken.get("access_token");
        String kakaoRefreshToken = (String) kakaoToken.get("refresh_token");
        // 필요하다면 expires_in, refresh_token_expires_in 도 꺼내서 저장

        // 3) 카카오 프로필 조회 (Optional)
        HttpHeaders profileHeaders = new HttpHeaders();
        profileHeaders.setBearerAuth(kakaoAccessToken);
        HttpEntity<Void> profileRequest = new HttpEntity<>(profileHeaders);
        ResponseEntity<Map> profileResponse = restTemplate.exchange(
                "https://kapi.kakao.com/v2/user/me",
                HttpMethod.GET,
                profileRequest,
                Map.class
        );
        Map<String,Object> kakaoAccount = (Map) profileResponse.getBody().get("kakao_account");
        String email    = (String) kakaoAccount.get("email");
        String nickname = (String)((Map)kakaoAccount.get("profile")).get("nickname");

        // 4) 사용자 조회/가입
        Member member = joinService.registerKakaoUserIfNotExist(email, nickname);

        // 5) 카카오 리프레시 토큰 저장
        refreshTokenService.saveToken(
                member.getUuid(),
                SocialType.KAKAO,
                kakaoRefreshToken
        );

        // 6) 자체 JWT 발급
        String ourAccessToken  = jwtUtil.generateAccessToken(member);
        String ourRefreshToken = jwtUtil.generateRefreshToken(member);
//        refreshTokenService.saveOurRefreshToken(user.getUuid(), ourRefreshToken);

        // 7) 클라이언트 응답 (헤더 + 쿠키 + 바디)
        response.setHeader(HttpHeaders.AUTHORIZATION, "Bearer " + ourAccessToken);

        String cookie = String.format(
                "refreshToken=%s; Path=/; HttpOnly; Max-Age=%d; SameSite=None",
                ourRefreshToken,
                jwtUtil.getRefreshExpiredMs()/1000
        );
        response.addHeader("Set-Cookie", cookie);

        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        TokenResponseVo vo = new TokenResponseVo(ourAccessToken, ourRefreshToken);
        response.getWriter().write(new ObjectMapper().writeValueAsString(vo));
    }
}
