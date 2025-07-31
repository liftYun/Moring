package com.dolijo.moring.member.controller;

import com.dolijo.moring.common.base.BaseResponse;
import com.dolijo.moring.common.base.BaseResponseStatus;
import com.dolijo.moring.member.entity.Member;
import com.dolijo.moring.security.dto.out.CustomMemberDetails;
import com.dolijo.moring.security.jwt.JWTUtil;
import com.dolijo.moring.security.service.CustomUserDetailsService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.data.repository.query.Param;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import com.dolijo.moring.security.jwt.JWTUtil;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/member")
@Tag(name = "회원", description = "회원 관련 API")
@Log4j2
public class MemberController {
    private final CustomUserDetailsService customUserDetailsService;
    private final JWTUtil jwtUtil;

    @Operation(summary = "회원의 닉네임 수정",   description = """
        회원의 닉네임을 수정합니다

        - api요청에 담겨있는 토큰에서 유저의 uuid를 뽑아냅니다.
        - uuid를 통해 닉네임을 업데이트 시킵니다.
        """)
    @PatchMapping("/update/{nickName}")
    public BaseResponse<Void> updateNickName(
            @Parameter(
                    name = "Authorization",
                    description = "임시 AccessToken",
                    required = false,
                    example = "0w6oYoZ-a9GOxnv3xXrOxtG9NrWJ24QBAAAAAQoNGZAAAAGYX4VHuVv0-avl6D9k"
            )
//            @RequestHeader(name = "Authorization", required = false) String authHeader,
            @AuthenticationPrincipal CustomMemberDetails customMemberDetails,
            @PathVariable String nickName
    ) {
//        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
//            throw new IllegalArgumentException("잘못된 인증 헤더입니다.");
//        }
        // "Bearer eyJ..." 에서 순수 토큰만 추출
//        String accessToken = authHeader.substring(7);

        // 예: jwtUtil 로 uuid 꺼내기
        String uuid = jwtUtil.getUserUuid(nickName);

        int result = customUserDetailsService.updateNickName(uuid, nickName);
        if(result == 1)  return BaseResponse.ok();
        // 성공시 다시 조회하거나 토큰을 재발행하는 등 추가 액션 필요
        else return BaseResponse.error(BaseResponseStatus.UPDATE_NICKNAME_FAIL);
    }

//    @PatchMapping("/update/{nickName}")
//    public BaseResponse<String> updateNickName(
//            @AuthenticationPrincipal CustomMemberDetails userDetails,
//            @PathVariable String nickName
//    ) {
//        // JwtAuthenticationFilter가 미리 토큰을 파싱해서 SecurityContext에 넣어두면
//        // userDetails.getUuid() 로 바로 uuid 획득 가능
//        String uuid = userDetails.getUuid();
//        String result = customUserDetailsService.updateNickName(uuid, nickName);
//        return BaseResponse.of(result);
//    }
}
