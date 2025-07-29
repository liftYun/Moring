package com.dolijo.moring.security.jwt;

import com.dolijo.moring.security.dto.in.MemberDetailRequestDto;
import com.dolijo.moring.security.dto.out.CustomMemberDetails;
import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

public class JWTFilter extends OncePerRequestFilter {

    private final JWTUtil jwtUtil;

    public JWTFilter(JWTUtil jwtUtil) {
        this.jwtUtil = jwtUtil;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) throws ServletException {
        // 인가 코드 콜백 URL을 JWT 검사에서 제외
        String path = request.getServletPath();
        return "/api/kakao/redirect".equals(path);
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain) throws ServletException, IOException {
        //request에서 Authorization 헤더를 찾음
        String authorization = request.getHeader("Authorization");

        // Authorization 헤더 검증
        if(authorization == null || !authorization.startsWith("Bearer ")) {
            filterChain.doFilter(request, response);

            // 조건 해당 시 메소드 종료
            return;
        }

        String token = authorization.split(" ")[1];

        // 토큰 소멸 시간 검증
        if(jwtUtil.isExpired(token)) {
            throw new JwtException("Access token expired");
        }

        //토큰에서 id, username과 role 획득
        String uuid = jwtUtil.getUserUuid(token);
        String userEmail = jwtUtil.getUserEmail(token);
        String userNickname = jwtUtil.getUserNickname(token);

        //user를 생성하여 값 set
        MemberDetailRequestDto memberDetailRequestDto = new MemberDetailRequestDto();
        memberDetailRequestDto.setUuid(uuid);
        memberDetailRequestDto.setEmail(userEmail);

        //UserDetails에 회원 정보 객체 담기
        CustomMemberDetails customMemberDetails = new CustomMemberDetails(MemberDetailRequestDto.from(memberDetailRequestDto));

        //스프링 시큐리티 인증 토큰 생성
        Authentication authToken = new UsernamePasswordAuthenticationToken(customMemberDetails, null, customMemberDetails.getAuthorities());
        //세션에 사용자 등록
        SecurityContextHolder.getContext().setAuthentication(authToken);

        filterChain.doFilter(request, response);
    }
}
