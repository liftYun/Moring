package com.dolijo.moring.member.controller;

import com.dolijo.moring.common.base.BaseResponse;
import com.dolijo.moring.common.base.BaseResponseStatus;
import com.dolijo.moring.member.entity.Member;
import com.dolijo.moring.member.valueobject.SocialType;
import com.dolijo.moring.security.dto.out.CustomMemberDetails;
import com.dolijo.moring.security.dto.out.MemberDetailResponseDto;
import com.dolijo.moring.security.jwt.JWTUtil;
import com.dolijo.moring.security.service.CustomUserDetailsService;
import com.dolijo.moring.security.vo.out.MemberDetailResponseVo;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.data.repository.query.Param;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import com.dolijo.moring.security.jwt.JWTUtil;

import java.sql.SQLException;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/members")
@Tag(name = "회원", description = "회원 관련 API")
@Log4j2
public class MemberController {
    private final CustomUserDetailsService customUserDetailsService;
    private final JWTUtil jwtUtil;

    @Operation(summary = "mypage 조회", description = "mypage 조회", tags = {"마이페이지"})
    @GetMapping("/mypage")
    public BaseResponse<MemberDetailResponseVo> list(
            @Parameter(description = "memberUuid", example = "63f912c8-2b04-11f0-a5b7-0242ac110002")
//            @PathVariable(name = "memberUuid")String memberuuid,
            @AuthenticationPrincipal CustomMemberDetails customMemberDetails
    ) throws SQLException {
        String memberuuid = customMemberDetails.getUserUuid();
        CustomMemberDetails memberDetails = customUserDetailsService.loadMemberUuid(memberuuid);
//        System.out.println("member?? : "+member);

        MemberDetailResponseVo member = new MemberDetailResponseVo(
                memberuuid,
                memberDetails.getUserEmail(),
                memberDetails.getUserNickname()
        );

        return BaseResponse.of(member);
    }


    @Operation(summary = "회원의 닉네임 수정", description = """
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
            @AuthenticationPrincipal CustomMemberDetails customMemberDetails,
            @PathVariable String nickName
    ) {
        String uuid = customMemberDetails.getUserUuid();

        // 예: jwtUtil 로 uuid 꺼내기
//        String uuid = jwtUtil.getUserUuid(nickName);

        int result = customUserDetailsService.updateNickName(uuid, nickName);
        if (result == 1) return BaseResponse.ok();
            // 성공시 다시 조회하거나 토큰을 재발행하는 등 추가 액션 필요
        else return BaseResponse.error(BaseResponseStatus.UPDATE_NICKNAME_FAIL);
    }

    @Operation(summary = "회원의 fcm token id 및 소셜타입 업데이트", description = "회원의 fcm token id와 소셜타입을 업데이트합니다.")
    @PatchMapping("/fcm")
    public BaseResponse<Void> fcmTokenUpdate(
            @Parameter(
                    name = "Authorization",
                    description = "임시 AccessToken",
                    required = false,
                    example = "0w6oYoZ-a9GOxnv3xXrOxtG9NrWJ24QBAAAAAQoNGZAAAAGYX4VHuVv0-avl6D9k"
            )
            @AuthenticationPrincipal CustomMemberDetails customMemberDetails,
            @Parameter(
                    name = "socialType",
                    description = "소셜 로그인 타입",
                    required = true,
                    example = "KAKAO",
                    schema = @Schema(
                            description = "소셜타입 : KAKAO, NAVER, GOOGLE, APPLE",
                            required = true,
                            allowableValues = {"KAKAO", "NAVER", "GOOGLE", "APPLE"}
                    )
            )
            @RequestParam("socialType") SocialType socialType,
            @Parameter(
                    name = "fcmTokenId",
                    description = "FCM 토큰 ID",
                    required = true,
                    example = "fcm_token_sample_123456"
            )
            @RequestParam("fcmTokenId") String fcmTokenId
    ) {
        String uuid = customMemberDetails.getUserUuid();
        customUserDetailsService.updateFcmTokenAndSocialType(uuid, fcmTokenId, socialType);
        return BaseResponse.ok();

    }


}
