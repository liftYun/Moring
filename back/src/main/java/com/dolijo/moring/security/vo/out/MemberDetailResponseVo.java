package com.dolijo.moring.security.vo.out;

import lombok.*;

@Getter
@AllArgsConstructor
@NoArgsConstructor
@ToString
@Builder
public class MemberDetailResponseVo {
    private Long id;
    private String username;
    private String password;
    private String role;
}
