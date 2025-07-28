package com.dolijo.moring.security.dto.in;

import com.dolijo.moring.member.entity.Member;
import com.dolijo.moring.member.entity.SocialMember;
import com.dolijo.moring.member.valueobject.SocialType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.Date;

@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class IssueRefreshTokenDto {
    private Long id;
//    private String uuid;
    private Member member;
    private String tokenId;
    private SocialType type;
    private Date expires;
    private Date created;

    public static SocialMember from(IssueRefreshTokenDto dto){
        return SocialMember.builder()
                .id(dto.id)
//                .memberUuid(dto.uuid)
                .member(dto.member)
                .type(dto.type)
                .tokenId(dto.tokenId)
                .expiresAt(dto.expires)
                .createdAt(dto.created)
                .build();
    }
}
