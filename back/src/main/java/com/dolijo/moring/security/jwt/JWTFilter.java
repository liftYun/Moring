package com.dolijo.moring.security.jwt;

import com.dolijo.moring.security.dto.in.MemberDetailRequestDto;
import com.dolijo.moring.security.dto.out.CustomMemberDetails;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Objects;

public class JWTFilter extends OncePerRequestFilter {

    private final JWTUtil jwtUtil;

    public JWTFilter(JWTUtil jwtUtil) {
        this.jwtUtil = jwtUtil;
    }

    // JWT 검사를 하지 않을 URL 목록
    private static final List<String> EXCLUDE_URLS = List.of(
            "/api/kakao/redirect",
            "/api/v1/auth/refresh"
    );

    // 토큰 조회에 사용할 키들
    private static final String BEARER_PREFIX = "Bearer ";
    private static final String TOKEN_QUERY_PARAM = "access_token";
    private static final List<String> TOKEN_COOKIE_NAMES = List.of("ACCESS_TOKEN", "Authorization");
    private static final String REQ_ATTR_TOKEN = "ACCESS_TOKEN";

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) throws ServletException {
        String path = request.getServletPath();
        return EXCLUDE_URLS.contains(path);
    }

    // ★ 비동기/에러 디스패치도 필터가 동작하도록 명시
    @Override
    protected boolean shouldNotFilterAsyncDispatch() { return false; }

    @Override
    protected boolean shouldNotFilterErrorDispatch() { return false; }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {

        // 이미 인증이 설정되어 있고, 재디스패치에서 Authorization이 없어도 그냥 통과시켜도 되지만
        // 아래 resolveToken이 다양한 경로로 토큰을 찾아 다시 보강해줌.
        String token = resolveToken(request);

        if (token == null || token.isBlank()) {
            // 토큰이 없어도 공개 경로나 permitAll 경로는 통과됨.
            filterChain.doFilter(request, response);
            return;
        }

        try {
            // (선택) 재사용을 위해 요청 속성에 저장 -> 재디스패치 시 활용될 수 있음
            request.setAttribute(REQ_ATTR_TOKEN, token);

            // 1) 만료 검사 (내부 파서에서 ExpiredJwtException이 날 수도 있음)
            if (jwtUtil.isExpired(token)) {
                writeJsonError(response, HttpServletResponse.SC_UNAUTHORIZED, "Access token expired");
                return;
            }

            // 2) 토큰에서 사용자 정보 추출
            String uuid         = jwtUtil.getUserUuid(token);
            String userEmail    = jwtUtil.getUserEmail(token);
            String userNickname = jwtUtil.getUserNickname(token);

            MemberDetailRequestDto memberDetailRequestDto = new MemberDetailRequestDto(
                    uuid, userEmail, userNickname
            );

            // 3) 인증 컨텍스트 세팅
            CustomMemberDetails userDetails = new CustomMemberDetails(
                    MemberDetailRequestDto.from(memberDetailRequestDto)
            );
            Authentication authToken = new UsernamePasswordAuthenticationToken(
                    userDetails, null, userDetails.getAuthorities()
            );
            SecurityContextHolder.getContext().setAuthentication(authToken);

            // 4) 다음 필터로
            filterChain.doFilter(request, response);

        } catch (ExpiredJwtException e) {
            writeJsonError(response, HttpServletResponse.SC_UNAUTHORIZED, "Access token expired");
        } catch (JwtException e) {
            writeJsonError(response, HttpServletResponse.SC_UNAUTHORIZED, "Invalid access token");
        }
    }

    /**
     * Authorization 헤더 → 쿼리파라미터 ?access_token= → 쿠키 → 요청 속성 순으로 토큰을 탐색.
     * (브라우저 EventSource는 Authorization 헤더를 못 붙이므로 쿼리파라미터/쿠키를 허용해야 함)
     */
    private String resolveToken(HttpServletRequest request) {
        // 1) Authorization 헤더
        String authz = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (authz != null && authz.startsWith(BEARER_PREFIX)) {
            return authz.substring(BEARER_PREFIX.length()).trim();
        }

        // 2) 쿼리 파라미터 (?access_token=...)
        String qp = request.getParameter(TOKEN_QUERY_PARAM);
        if (qp != null && !qp.isBlank()) {
            return qp.trim();
        }

        // 3) 쿠키
        Cookie[] cookies = request.getCookies();
        if (cookies != null) {
            for (Cookie c : cookies) {
                if (TOKEN_COOKIE_NAMES.contains(c.getName()) && c.getValue() != null && !c.getValue().isBlank()) {
                    String v = c.getValue().trim();
                    // 어떤 환경은 "Bearer xxx" 형태로 저장되어 있을 수 있음
                    if (v.startsWith(BEARER_PREFIX)) v = v.substring(BEARER_PREFIX.length()).trim();
                    return v;
                }
            }
        }

        // 4) 앞선 디스패치에서 저장해둔 요청 속성
        Object attr = request.getAttribute(REQ_ATTR_TOKEN);
        if (attr instanceof String s && !s.isBlank()) {
            return s.trim();
        }

        return null;
    }

    private void writeJsonError(HttpServletResponse response, int status, String message) throws IOException {
        response.setStatus(status);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        String body = "{\"error\":\"" + escape(message) + "\"}";
        response.getWriter().write(body);
    }

    private String escape(String s) {
        return Objects.toString(s, "").replace("\"", "\\\"");
    }
}
