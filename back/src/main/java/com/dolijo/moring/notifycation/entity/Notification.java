package com.dolijo.moring.notifycation.entity;

import com.dolijo.moring.common.base.BaseEntity;
import com.dolijo.moring.member.entity.Member;
import com.dolijo.moring.member.valueobject.GeneralNotificationType;
import com.dolijo.moring.member.valueobject.SocialType;
import com.dolijo.moring.notifycation.valueobject.NotificationType;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.ColumnDefault;
import org.hibernate.annotations.Comment;

@Entity
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "notification")
public class Notification extends BaseEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_uuid", referencedColumnName = "member_uuid", nullable = false)
    private Member member;

    @Enumerated(EnumType.STRING)
    @Column(name = "notification_type", nullable = false)
    @Comment("알람 유형")
    private NotificationType notificationType;

    @Enumerated(EnumType.STRING)
    @Column(name = "general_notification_type", nullable = false)
    @Comment("일반 알람 유형")
    private GeneralNotificationType generalNotificationType;

    @Column(name = "read_flag", nullable = false)
    @Comment("읽음 여부")
    @ColumnDefault("false")
    private Boolean readFlag;

}
