package com.dolijo.moring.security.vo.out;

import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public class SocialMemberCheckVo {
    private Long id;
    private String uuid;
    private String token;
}