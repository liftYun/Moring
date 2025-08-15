package com.dolijo.moring.notifycation.dto.out;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
public class UnauthorizedUserResponseDto {

    private String nickname; // 차량 닉네임

    private LocalDateTime detectedAt; // 탐지시간

    private String unauthorizedUserImgUrl; // 비인가 사용자 이미지 URL
}