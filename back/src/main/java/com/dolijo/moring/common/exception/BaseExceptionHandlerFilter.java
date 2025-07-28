package com.dolijo.moring.common.exception;

import com.dolijo.moring.common.base.BaseResponse;
import com.dolijo.moring.common.base.BaseResponseStatus;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.NonNull;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import javax.security.sasl.AuthenticationException;
import java.io.IOException;

@Slf4j
@Component
public class BaseExceptionHandlerFilter extends OncePerRequestFilter {// 매 요청마다 한 번만 실행되는 필터 클래스 상속

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest request, @NonNull HttpServletResponse response,
                                    @NonNull FilterChain filterChain) throws ServletException, IOException {
        try {
            filterChain.doFilter(request, response); // 다음 필터 또는 실제 서블릿을 실행
        } catch (BaseException e) {  // 커스텀 예외(BaseException) 발생 시 처리
            log.error("BaseException -> {}({})", e.getStatus(), e.getStatus().getMessage(), e);
            setErrorResponse(response, e);
        } catch (AuthenticationException e) { // 추후 스프링 시큐리티를 위해 미리 작성
            log.error("AuthenticationException -> {}", e.getMessage(), e);
            setErrorResponse(response, new BaseException(BaseResponseStatus.NO_SIGN_IN));
        }
    }

    // 에러 응답을 설정 메서드
    private void setErrorResponse(HttpServletResponse response,
                                  BaseException be) {
        ObjectMapper objectMapper = new ObjectMapper();
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        BaseResponse<BaseResponseStatus> baseResponse = new BaseResponse<>(be.getStatus());
        try {
            response.getWriter().write(objectMapper.writeValueAsString(baseResponse));
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

}