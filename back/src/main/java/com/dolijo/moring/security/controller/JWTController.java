package com.dolijo.moring.security.controller;

import com.dolijo.moring.common.base.BaseEntity;
import com.dolijo.moring.common.base.BaseResponse;
import com.dolijo.moring.security.jwt.JWTUtil;
import com.dolijo.moring.security.service.JoinService;
import com.dolijo.moring.security.service.SocialMemberService;
import com.dolijo.moring.security.vo.in.RegistRequestVo;
import io.jsonwebtoken.Claims;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.log4j.Log4j2;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@Log4j2
@RequestMapping("/api/v1/auth")
@Tag(name = "회원", description = "회원 관련 API")
public class JWTController {

    private final JWTUtil jwtUtil;

    private final JoinService joinService;

    private final SocialMemberService socialMemberService;


    public JWTController(JWTUtil jwtUtil, JoinService joinService, SocialMemberService socialMemberService) {
        this.jwtUtil = jwtUtil;
        this.joinService = joinService;
        this.socialMemberService = socialMemberService;
    }

//    @PostMapping("/logout/aToken")
//    public ResponseEntity<?> logout(
//            @AuthenticationPrincipal CustomUserDetails user,
//            HttpServletResponse response
//    ) {
//        refreshTokenService.deleteToken(user.getUserUuid());
//        // 쿠키 만료 처리
//        Cookie cookie = new Cookie("refreshToken", null);
//        cookie.setHttpOnly(true);
//        cookie.setPath("/");
//        cookie.setMaxAge(0);
//        response.addCookie(cookie);
//        return ResponseEntity.ok().build();
//    }

//    @PostMapping("/logout/rToken")
//    public ResponseEntity<?> logout(
//            @CookieValue(name="refreshToken", required=true) String refreshToken,
//            HttpServletResponse response
//    ) {
//        Claims claims = jwtUtil.parseClaims(refreshToken);
//        System.out.println("logout to Refresh Token : " + claims);
//        String uuid = claims.get("uuid", String.class);
//        socialMemberService.deleteToken(uuid);
//
//        // 쿠키 만료 처리
//        Cookie cookie = new Cookie("refreshToken", null);
//        cookie.setHttpOnly(true);
//        cookie.setPath("/");
//        cookie.setMaxAge(0);
//        response.addCookie(cookie);
//        return ResponseEntity.ok().build();
//    }

    @PostMapping("/logout/rToken")
    @Operation(summary = "로그아웃",   description = """
        회원의 요청에 따라 로그아웃을 합니다

        - 자동로그인 유무와 관계없이 등록된 RefreshToken을 지웁니다.
        - 클라이언트가 보유한 토큰들은 클라이언트단에서 자체 폐기 로직이 실행됩니다.
        """)
    public BaseResponse<?> logout(
            @CookieValue(name="refreshToken", required=true) String refreshToken,
            HttpServletResponse response
    ) {
        Claims claims = jwtUtil.parseClaims(refreshToken);
        System.out.println("logout to Refresh Token : " + claims);
        String memberUui = claims.get("uuid", String.class);
//        Long id = claims.get("id", Long.class);
        socialMemberService.deleteToken(memberUui);

        // 쿠키 만료 처리
        Cookie cookie = new Cookie("refreshToken", null);
        cookie.setHttpOnly(true);
        cookie.setPath("/");
        cookie.setMaxAge(0);
        response.addCookie(cookie);
        return BaseResponse.ok();
    }
//    @PostMapping("/join")
//    public String joinProcess(@RequestBody RegistRequestVo vo) {
//
//        joinService.joinProcess(RegistRequestVo.from(vo));
//
//        return "ok";
//    }

}
