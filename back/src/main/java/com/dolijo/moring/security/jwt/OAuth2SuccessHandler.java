//package com.dolijo.moring.security.jwt;
//
//import com.dolijo.moring.member.entity.Member;
//import com.dolijo.moring.member.valueobject.SocialType;
//import com.dolijo.moring.security.service.JoinService;
//import com.dolijo.moring.security.service.SocialMemberService;
//import com.dolijo.moring.security.vo.out.TokenResponseVo;
//import com.fasterxml.jackson.databind.ObjectMapper;
//import jakarta.servlet.http.HttpServletRequest;
//import jakarta.servlet.http.HttpServletResponse;
//import org.springframework.boot.web.client.RestTemplateBuilder;
//import org.springframework.http.*;
//import org.springframework.security.core.Authentication;
//import org.springframework.security.web.authentication.AuthenticationSuccessHandler;
//import org.springframework.stereotype.Component;
//import org.springframework.util.LinkedMultiValueMap;
//import org.springframework.util.MultiValueMap;
//import org.springframework.web.client.RestTemplate;
//
//import java.io.IOException;
//import java.time.LocalDateTime;
//import java.util.Date;
//import java.util.Map;
//
///**
// n * OAuth2 로그인 성공 시 카카오에서 받은 사용자 정보를 기반으로 회원가입/조회 후 JWT 발급 및 응답 처리
// */
//@Component
//public class OAuth2SuccessHandler implements AuthenticationSuccessHandler {
//
//    private final JWTUtil jwtUtil;
//    private final SocialMemberService socialMemberService;
//    private final JoinService joinService;
//    private final RestTemplate restTemplate;      // RestTemplate 혹은 WebClient
//    private final String kakaoClientId;           // application.yml 에서 주입
//    private final String kakaoRedirectUri;
//
//    public OAuth2SuccessHandler(
//            JWTUtil jwtUtil,
//            SocialMemberService socialMemberService,
//            JoinService joinService,
//            RestTemplateBuilder restTemplateBuilder,
//            KakaoOAuth2Properties props
////            @Value("${spring.security.oauth2.client.registration.kakao.clientId}") String kakaoClientId,
////            @Value("${spring.security.oauth2.client.registration.kakao.redirectUri}") String kakaoRedirectUri
//    ) {
//        this.jwtUtil  = jwtUtil;
//        this.socialMemberService = socialMemberService;
//        this.joinService = joinService;
//        this.restTemplate = restTemplateBuilder.build();
////        this.kakaoClientId = kakaoClientId;
////        this.kakaoRedirectUri = kakaoRedirectUri;
//        this.kakaoClientId  = props.getClientId();
//        this.kakaoRedirectUri = props.getRedirectUri();
//
//    }
//
//    @Override
//    public void onAuthenticationSuccess(
//            HttpServletRequest request,
//            HttpServletResponse response,
//            Authentication authentication
//    ) throws IOException {
//
//        // 1) 인가 코드 꺼내기
//        String authorizationCode = request.getParameter("code");
//
//        // 2) 카카오 토큰 엔드포인트에 POST → 카카오 액세스/리프레시 토큰 교환
//        MultiValueMap<String,String> form = new LinkedMultiValueMap<>();
//        form.add("grant_type",   "authorization_code");
//        form.add("client_id",    kakaoClientId);
//        form.add("redirect_uri", kakaoRedirectUri);
//        form.add("code",         authorizationCode);
//
//        HttpHeaders headers = new HttpHeaders();
//        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);
//
//        HttpEntity<MultiValueMap<String,String>> tokenRequest =
//                new HttpEntity<>(form, headers);
//
//        // 카카오 토큰 응답을 Map 으로 받되, 실제로는 DTO 를 만들어 쓰셔도 좋습니다.
//        ResponseEntity<Map> tokenResponse = restTemplate.exchange(
//                "https://kauth.kakao.com/oauth/token",
//                HttpMethod.POST,
//                tokenRequest,
//                Map.class
//        );
//
//        Map<String,Object> kakaoToken = tokenResponse.getBody();
//        String kakaoAccessToken  = (String) kakaoToken.get("access_token");
//        String kakaoRefreshToken = (String) kakaoToken.get("refresh_token");
//        Number refreshExpiresInSec = (Number) kakaoToken.get("refresh_token_expires_in");
//
//        LocalDateTime kakaoRefreshExpiresAt = LocalDateTime.now()
//                .plusSeconds(refreshExpiresInSec.longValue());
//
//
//        // 3) 카카오 프로필 조회 (Optional)
//        HttpHeaders profileHeaders = new HttpHeaders();
//        profileHeaders.setBearerAuth(kakaoAccessToken);
//        HttpEntity<Void> profileRequest = new HttpEntity<>(profileHeaders);
//        ResponseEntity<Map> profileResponse = restTemplate.exchange(
//                "https://kapi.kakao.com/v2/user/me",
//                HttpMethod.GET,
//                profileRequest,
//                Map.class
//        );
//        Map<String,Object> kakaoAccount = (Map) profileResponse.getBody().get("kakao_account");
//        String email    = (String) kakaoAccount.get("email");
//        String nickname = (String)((Map)kakaoAccount.get("profile")).get("nickname");
//
//        // 4) 사용자 조회/가입
//        Member member = joinService.registerKakaoUserIfNotExist(email, nickname);
//
//        // 5) 카카오 리프레시 토큰 저장
//        socialMemberService.saveToken(
//                member.getUuid(),
//                SocialType.KAKAO,
//                kakaoRefreshToken,
//                kakaoRefreshExpiresAt
//        );
//
//        // 6) 자체 JWT 발급
//        String ourAccessToken  = jwtUtil.generateAccessToken(member);
//        String ourRefreshToken = jwtUtil.generateRefreshToken(member);
////        refreshTokenService.saveOurRefreshToken(user.getUuid(), ourRefreshToken);
//
//        // 7) 클라이언트 응답 (헤더 + 쿠키 + 바디)
//        response.setHeader(HttpHeaders.AUTHORIZATION, "Bearer " + ourAccessToken);
//
//        String cookie = String.format(
//                "refreshToken=%s; Path=/; HttpOnly; Max-Age=%d; SameSite=None",
//                ourRefreshToken,
//                jwtUtil.getRefreshExpiredMs()/1000
//        );
//        response.addHeader("Set-Cookie", cookie);
//
//        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
//        TokenResponseVo vo = new TokenResponseVo(ourAccessToken, ourRefreshToken);
//        response.getWriter().write(new ObjectMapper().writeValueAsString(vo));
//    }
//}

package com.dolijo.moring.security.jwt;

import com.dolijo.moring.member.entity.Member;
import com.dolijo.moring.member.valueobject.SocialType;
import com.dolijo.moring.security.service.JoinService;
import com.dolijo.moring.security.service.SocialMemberService;
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
import java.net.URLEncoder;
import java.time.LocalDateTime;
import java.util.Map;

@Component
public class OAuth2SuccessHandler implements AuthenticationSuccessHandler {

    private final JWTUtil jwtUtil;
    private final SocialMemberService socialMemberService;
    private final JoinService joinService;
    private final RestTemplate restTemplate;
    private final String kakaoClientId;
    private final String kakaoRedirectUri;
    private final String kakaoClientSecret;
    private final ObjectMapper objectMapper;

    public OAuth2SuccessHandler(
            JWTUtil jwtUtil,
            SocialMemberService socialMemberService,
            JoinService joinService,
            RestTemplateBuilder restTemplateBuilder,
            KakaoOAuth2Properties props,
            ObjectMapper objectMapper
    ) {
        this.jwtUtil  = jwtUtil;
        this.socialMemberService = socialMemberService;
        this.joinService = joinService;
        this.restTemplate = restTemplateBuilder.build();
        this.kakaoClientId  = props.getClientId();
        this.kakaoClientSecret = props.getClientSecret();
        this.kakaoRedirectUri = props.getRedirectUri();
        this.objectMapper = objectMapper;
    }

    @Override
    public void onAuthenticationSuccess(
            HttpServletRequest request,
            HttpServletResponse response,
            Authentication authentication
    ) throws IOException {

        System.out.println("리다이렉트 URL : "+kakaoRedirectUri);

        // 1) 인가 코드 추출
        String code = request.getParameter("code");

        // 2) 카카오 토큰 교환
        MultiValueMap<String,String> form = new LinkedMultiValueMap<>();
        form.add("grant_type",   "authorization_code");
        form.add("client_id",    kakaoClientId);
        form.add("client_secret", kakaoClientSecret);
        form.add("redirect_uri", kakaoRedirectUri);
        form.add("code",         code);

        HttpHeaders tokenHeaders = new HttpHeaders();
        tokenHeaders.setContentType(MediaType.APPLICATION_FORM_URLENCODED);

        ResponseEntity<Map> tokenResp = restTemplate.exchange(
                "https://kauth.kakao.com/oauth/token",
                HttpMethod.POST,
                new HttpEntity<>(form, tokenHeaders),
                Map.class
        );
        Map<String, Object> kakaoTokens = tokenResp.getBody();
        String kakaoAccessToken  = (String) kakaoTokens.get("access_token");
        String kakaoRefreshToken = (String) kakaoTokens.get("refresh_token");
        Number expiresInSec      = (Number) kakaoTokens.get("refresh_token_expires_in");
        LocalDateTime kakaoRefreshExpiresAt = LocalDateTime.now()
                .plusSeconds(expiresInSec.longValue());

        // 3) 카카오 프로필 조회
        HttpHeaders profileHeaders = new HttpHeaders();
        profileHeaders.setBearerAuth(kakaoAccessToken);
        ResponseEntity<Map> profileResp = restTemplate.exchange(
                "https://kapi.kakao.com/v2/user/me",
                HttpMethod.GET,
                new HttpEntity<>(profileHeaders),
                Map.class
        );
        Map<String,Object> account = (Map) profileResp.getBody().get("kakao_account");
        String email    = (String) account.get("email");
        String nickname = (String)((Map)account.get("profile")).get("nickname");

        // 4) 회원 가입 또는 조회
        Member member = joinService.registerKakaoUserIfNotExist(email, nickname);

        // 5) **카카오 리프레시 토큰** DB에 저장
        socialMemberService.saveToken(
                member.getUuid(),
                SocialType.KAKAO,
                kakaoRefreshToken,
                kakaoRefreshExpiresAt
        );

        // 6) **자체 JWT** 발급
        String ourAccessToken  = jwtUtil.generateAccessToken(member);
        String ourRefreshToken = jwtUtil.generateRefreshToken(member);

//        // 7) 클라이언트 응답 구성
//        //   - Authorization 헤더
//        response.setHeader(HttpHeaders.AUTHORIZATION, "Bearer " + ourAccessToken);
//        //   - refreshToken은 HttpOnly 쿠키로
//        String cookie = String.format(
//                "refreshToken=%s; Path=/; HttpOnly; SameSite=None; Max-Age=%d",
//                ourRefreshToken,
//                jwtUtil.getRefreshExpiredMs() / 1000
//        );
//        response.addHeader(HttpHeaders.SET_COOKIE, cookie);
//
//        //   - JSON 바디에도 accessToken 포함
//        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
//        objectMapper.writeValue(response.getWriter(),
//                new TokenResponseVo(ourAccessToken, ourRefreshToken)
//        );

        // ▶ 1) 커스텀 스킴 URI 조립
        String appCallbackScheme = "moring";
        String appCallbackPath = "/login/oauth2/code/kakao";
        String appRedirect = appCallbackScheme
                + appCallbackPath
                + "?token="   + URLEncoder.encode(ourAccessToken,  "UTF-8")
                + "&refresh_token=" + URLEncoder.encode(ourRefreshToken, "UTF-8");
        System.out.println(appRedirect);
        // ▶ 2) 브라우저에 302 리다이렉트 응답
        response.setStatus(HttpServletResponse.SC_FOUND);
        response.setHeader(HttpHeaders.LOCATION, appRedirect);
    }
}
