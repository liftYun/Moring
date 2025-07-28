package com.dolijo.moring.member.entity;

import com.dolijo.moring.common.base.BaseEntity;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.Comment;

@Entity
@AllArgsConstructor
@NoArgsConstructor
@Table(
        name = "member",
        indexes = {
                @Index(name = "idx_member_uuid", columnList = "member_uuid", unique = true)
        }
)
public class Member extends BaseEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    @Column(name = "member_uuid", nullable = false, length = 40)
    @Comment("회원 UUID")
    private String memberUuid;

    
    @Column(nullable = false, length = 40, unique = true)
    @Comment("회원 이메일")
    private String email;

    @Column(nullable = false, length = 30)
    @Comment("닉네임")
    private String nickName;

    @Builder
    public Member(String memberUuid, String email, String nickName) {
        this.memberUuid = memberUuid;
        this.email = email;
        this.nickName = nickName;
    }
}
