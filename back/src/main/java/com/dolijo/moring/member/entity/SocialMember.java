package com.dolijo.moring.member.entity;
import com.dolijo.moring.member.valueobject.SocialType;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.Comment;

import java.time.LocalDateTime;


@Entity
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "social_member")
@Getter
public class SocialMember {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id")
    private Member member;

    @Enumerated(EnumType.STRING)
    @Column(name = "type", nullable = false)
    @Comment("소셜 로그인  유형")
    private SocialType type;

    @Column(name = "token_id" , nullable = false)
    @Comment("소셜인증 토큰값")
    private String tokenId;

    /** 토큰 만료 시각 */
    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;

    /** 생성 시각 */
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }

    @Builder
    public SocialMember(Member member, SocialType type, String tokenId, LocalDateTime expiresAt, LocalDateTime createdAt) {
        this.member = member;
        this.tokenId = tokenId;
        this.type = type;
        this.expiresAt = expiresAt;
        this.createdAt = createdAt;
    }
}
