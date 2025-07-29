package com.dolijo.moring.security.vo.out;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

/**
 * 카카오 OAuth2 토큰 발급 응답을 매핑하는 VO
 */
@Data
public class KakaoTokenResponseVo {
    @JsonProperty("access_token")
    private String accessToken;

    @JsonProperty("refresh_token")
    private String refreshToken;

    @JsonProperty("token_type")
    private String tokenType;

    @JsonProperty("expires_in")
    private Long expiresIn;

    @JsonProperty("refresh_token_expires_in")
    private Long refreshTokenExpiresIn;

    @JsonProperty("scope")
    private String scope;
}