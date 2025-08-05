package com.dolijo.moring.notifycation.entity;

import com.dolijo.moring.car.entity.Car;
import com.dolijo.moring.common.base.BaseEntity;
import com.dolijo.moring.notifycation.valueobject.NotificationDetailType;
import com.dolijo.moring.notifycation.valueobject.NotificationType;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.ColumnDefault;
import org.hibernate.annotations.Comment;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

@Entity
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "notification")
public class Notification extends BaseEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "car_id", nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private Car car;

    @Enumerated(EnumType.STRING)
    @Column(name = "notification_type", nullable = false)
    @Comment("알람 유형")
    private NotificationType notificationType;

    @Enumerated(EnumType.STRING)
    @Column(name = "notification_detail", nullable = false)
    @Comment("알림 상세 유형")
    private NotificationDetailType notificationDetail;

    @Column(name = "read_flag", nullable = false)
    @Comment("읽음 여부")
    @ColumnDefault("false")
    private Boolean readFlag;

    @Column(name = "message", nullable = true)
    @Comment("알림 메시지")
    private String message;

    @Builder
    public Notification(Car car, NotificationType notificationType, NotificationDetailType notificationDetail, String message, Boolean readFlag) {
        this.car = car;
        this.notificationType = notificationType;
        this.notificationDetail = notificationDetail;
        this.message = message;
        this.readFlag = readFlag;
    }
}
