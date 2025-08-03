package com.dolijo.moring.security.jwt;

import com.dolijo.moring.security.dto.out.CustomMemberDetails;
import com.dolijo.moring.member.valueobject.SocialType;
import com.dolijo.moring.security.dto.out.SocialMemberResponseDto;
import com.dolijo.moring.security.service.SocialMemberService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

import java.io.IOException;
import java.time.LocalDateTime;
import java.util.Collection;
import java.util.Iterator;

public class LoginFilter extends UsernamePasswordAuthenticationFilter {

    private final AuthenticationManager authenticationManager;
    private final JWTUtil jwtUtil;
    private final SocialMemberService socialMemberService;

    public LoginFilter(AuthenticationManager authenticationManager, JWTUtil jwtUtil, SocialMemberService socialMemberService) {
        this.authenticationManager = authenticationManager;
        this.jwtUtil = jwtUtil;
        this.socialMemberService = socialMemberService;
    }

    @Override
    public Authentication attemptAuthentication(HttpServletRequest request, HttpServletResponse response) throws AuthenticationException {

        String userEmail = obtainUsername(request);
        String password = obtainPassword(request);

        UsernamePasswordAuthenticationToken authToken = new UsernamePasswordAuthenticationToken(userEmail, password, null);

        return authenticationManager.authenticate(authToken);
    }

    //로그인 성공시 실행하는 메소드 (여기서 JWT를 발급)
    @Override
    protected void successfulAuthentication(HttpServletRequest request,
                                            HttpServletResponse response,
                                            FilterChain chain,
                                            Authentication authentication) throws IOException {

        CustomMemberDetails customMemberDetails = (CustomMemberDetails) authentication.getPrincipal();
        SocialMemberResponseDto refreshTokenResponseDto = (SocialMemberResponseDto) authentication.getCredentials();

        String userEmail = customMemberDetails.getUserEmail();
        String nickname = customMemberDetails.getUserNickname();
        String uuid = customMemberDetails.getUserUuid();
//        Long id = customMemberDetails.getMemberId();
        SocialType type = refreshTokenResponseDto.getType();

        Collection<? extends GrantedAuthority> authorities = authentication.getAuthorities();
        Iterator<? extends GrantedAuthority> iterator = authorities.iterator();
        GrantedAuthority auth = iterator.next();

        String role = auth.getAuthority();

        String accessToken = jwtUtil.createAccessToken(uuid, nickname);
        String refreshToken = jwtUtil.createRefreshToken(uuid);
        LocalDateTime expiresAt = LocalDateTime.now().plusDays(30);

        // Refresh Token 을 DB 혹은 Redis 등에 저장 (토큰 회수/무효화 위해)
        socialMemberService.saveToken(uuid, type, refreshToken, expiresAt);

        response.addHeader("Authorization", "Bearer " + accessToken);

        Cookie refreshCookie = new Cookie("refreshToken", refreshToken);
        refreshCookie.setHttpOnly(true);
        refreshCookie.setPath("/");
        refreshCookie.setMaxAge((int)(jwtUtil.getRefreshExpiredMs() / 1000));
        response.addCookie(refreshCookie);
    }

    //로그인 실패시 실행하는 메소드
    // 추후 추가적인 실패시 기능 추가 가능
    @Override
    protected void unsuccessfulAuthentication(HttpServletRequest request, HttpServletResponse response, AuthenticationException failed) {

        response.setStatus(401);
    }
}
