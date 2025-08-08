package com.dolijo.moring.security.jwt;

import com.dolijo.moring.security.dto.in.MemberDetailRequestDto;
import com.dolijo.moring.security.dto.out.CustomMemberDetails;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

public class JWTFilter extends OncePerRequestFilter {

    private final JWTUtil jwtUtil;

    public JWTFilter(JWTUtil jwtUtil) {
        this.jwtUtil = jwtUtil;
    }

    // JWT 검사를 하지 않을 URL 목록
    private static final List<String> EXCLUDE_URLS = List.of(
            "/api/kakao/redirect",
            "/api/v1/auth/refresh"   // ← 여길 추가!
    );

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) throws ServletException {
        // 인가 코드 콜백 URL을 JWT 검사에서 제외
        String path = request.getServletPath();
        return EXCLUDE_URLS.contains(path);
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

        try {
            // 2) 만료 검사
            if (jwtUtil.isExpired(token)) {
                // 2-1) 만료된 경우 401 응답
                response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                response.setContentType(MediaType.APPLICATION_JSON_VALUE);
                response.getWriter()
                        .write("{\"error\":\"Access token expired\"}");
                return;
            }

            // 3) 토큰에서 사용자 정보 파싱
            String uuid         = jwtUtil.getUserUuid(token);
            String userEmail    = jwtUtil.getUserEmail(token);
            String userNickname = jwtUtil.getUserNickname(token);

            MemberDetailRequestDto memberDetailRequestDto= new MemberDetailRequestDto(
                    uuid,
                    userEmail,
                    userNickname
            );

            // 4) 스프링 시큐리티 컨텍스트에 인증 정보 세팅
            CustomMemberDetails userDetails =
                    new CustomMemberDetails(
                            MemberDetailRequestDto.from(memberDetailRequestDto)
                    );
            Authentication authToken = new UsernamePasswordAuthenticationToken(
                    userDetails, null, userDetails.getAuthorities()
            );
            SecurityContextHolder.getContext().setAuthentication(authToken);

            // 5) 정상 처리 시 다음 필터로
            filterChain.doFilter(request, response);

        } catch (ExpiredJwtException e) {
            // parser 내부에서 만료 예외가 터질 경우에도 401
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
            response.getWriter().write("{\"error\":\"Access token expired\"}");

        } catch (JwtException e) {
            // 6) 토큰 유효하지 않음(서명 불일치 등)이면 401 응답
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
            response.getWriter()
                    .write("{\"error\":\"Invalid access token\"}");
        }
    }
}
