package com.dolijo.moring.security.vo.in;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * 클라이언트에서 전달된 카카오 인가 코드를 담는 요청 VO
 */
@Getter
@Setter
@NoArgsConstructor
public class OAuthCodeRequestVo {
    /**
     * 카카오 인가 코드
     */
    private String code;
}