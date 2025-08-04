package com.dolijo.moring.security.vo.out;

import lombok.*;

@Getter
@AllArgsConstructor
@NoArgsConstructor
@ToString
@Builder
public class MemberDetailResponseVo {
    private String uuid;
    private String email;
    private String nickName;
}
