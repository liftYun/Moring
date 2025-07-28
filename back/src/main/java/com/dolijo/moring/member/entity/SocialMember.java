package com.dolijo.moring.member.entity;

import com.dolijo.moring.common.base.BaseEntity;
import com.dolijo.moring.member.entity.valueobject.SocialType;
import com.dolijo.moring.part.entity.valueobject.PartType;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.Comment;

import static jakarta.persistence.FetchType.LAZY;

@Entity
@AllArgsConstructor
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "social_member")
public class SocialMember {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_uuid", referencedColumnName = "member_uuid", nullable = false)
    private Member member;

    @Enumerated(EnumType.STRING)
    @Column(name = "type", nullable = false)
    @Comment("소셜 로그인  유형")
    private SocialType type;

    @Column(name = "token_id" , nullable = false)
    @Comment("소셜인증 토큰값")
    private String tokenId;
}
