package com.dolijo.moring.sms.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UnauthorizedUserAlertLmsRequestDto {
    @Schema(description = "차대 번호", example = "KNMK5C2HMLP000437")
    private String vin;

    @Schema(description = "이미지URL", example = "https://example.com/image.jpg")
    private String imageUrl; // 이미지 URL
}

