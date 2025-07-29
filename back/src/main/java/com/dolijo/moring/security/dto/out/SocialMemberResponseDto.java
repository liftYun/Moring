package com.dolijo.moring.security.dto.out;

import com.dolijo.moring.member.entity.Member;
import com.dolijo.moring.member.entity.SocialMember;
import com.dolijo.moring.member.valueobject.SocialType;
import lombok.Builder;
import lombok.Getter;

import java.util.Date;

@Getter
@Builder
public class SocialMemberResponseDto {
    private Long id;
    private Member uuid;
    private SocialType type;
    private String token;
    private Date expiresAt;

    public static SocialMemberResponseDto from(SocialMember entity){
        return SocialMemberResponseDto.builder()
                .id(entity.getId())
                .uuid(entity.getMember())
                .type(entity.getType())
                .token(entity.getTokenId())
                .expiresAt(entity.getExpiresAt())
                .build();
    }
}
