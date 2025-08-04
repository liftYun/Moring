package com.dolijo.moring.security.dto.in;

import com.dolijo.moring.member.entity.Member;
import lombok.*;

@Setter
@AllArgsConstructor
@NoArgsConstructor
@ToString
@Builder
public class MemberDetailRequestDto {
    private String uuid;
    private String nickName;
    private String email;

    public static Member from(MemberDetailRequestDto dto){
        return Member.builder()
                .uuid(dto.uuid)
                .email(dto.email)
                .nickName(dto.nickName)
                .build();
    }

}
