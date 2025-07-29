package com.dolijo.moring.security.dto.in;

import com.dolijo.moring.member.entity.Member;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@AllArgsConstructor
@NoArgsConstructor
@Builder
public class RegistRequestDto {
    private Long id;
    private String nickName;
    private String email;

    public static Member from(RegistRequestDto dto){
        return Member.builder()
//                .id(dto.id)
                .nickName(dto.nickName)
                .email(dto.email)
                .build();
    }


}
