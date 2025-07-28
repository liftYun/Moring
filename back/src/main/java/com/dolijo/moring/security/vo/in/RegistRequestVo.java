package com.dolijo.moring.security.vo.in;

import com.dolijo.moring.security.dto.in.RegistRequestDto;
import lombok.Builder;
import lombok.Getter;

//@Setter
@Getter
@Builder
public class RegistRequestVo {
    private String nickname;
    private String userEmail;

    public static RegistRequestDto from(RegistRequestVo vo){

        return RegistRequestDto.builder()
                .nickName(vo.nickname)
                .email(vo.userEmail)
                .build();

    }

}
