package com.dolijo.moring.security.dto.in;

import com.dolijo.moring.member.entity.Member;
import lombok.*;

@Setter
@AllArgsConstructor
@NoArgsConstructor
@ToString
@Builder
public class UserDetailRequestDto {
    private Long id;
    private String uuid;
    private String nickName;
    private String email;

    public static Member from(UserDetailRequestDto dto){
        return Member.builder()
                .id(dto.id)
                .uuid(dto.uuid)
                .email(dto.email)
                .build();
    }
}
