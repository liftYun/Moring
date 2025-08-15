package com.dolijo.moring.notifycation.dto.in;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public class UnauthorizedUserRequestDto {
    @Schema(description = "차량 VIN", required = true, example = "KNMK5C2HMLP000437")
    private String vin;
    @Schema(description = "비인가 사용자 이미지 url", required = false, example = "https://example.com/unauthorized_user.jpg")
    private String unauthorizedUserImgUrl;
}
