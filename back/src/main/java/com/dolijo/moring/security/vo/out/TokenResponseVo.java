package com.dolijo.moring.security.vo.out;

import lombok.AllArgsConstructor;
import lombok.Data;

/**
 * AccessToken 및 RefreshToken을 응답으로 전달하는 VO
 */
@Data
@AllArgsConstructor
public class TokenResponseVo {
    private String accessToken;
    private String refreshToken;
}