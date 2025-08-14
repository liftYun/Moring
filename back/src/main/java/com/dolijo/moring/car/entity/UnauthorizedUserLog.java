package com.dolijo.moring.car.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.Comment;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

import java.time.LocalDateTime;

@Entity
@Table(name = "unauthorized_user_log")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class UnauthorizedUserLog {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "car_id")
    @OnDelete(action = OnDeleteAction.CASCADE)
    private Car car;

    @Column(name = "created_at", nullable = false, updatable = false)
    @Comment("생성일")
    private LocalDateTime createdAt;

    @Column(nullable = false)
    @Comment("비인가 사용자 이미지 URL")
    private String unauthorizedUserImgUrl;

    @Builder
    public UnauthorizedUserLog(Car car, LocalDateTime createdAt, String unauthorizedUserImgUrl) {
        this.car = car;
        this.createdAt = createdAt;
        this.unauthorizedUserImgUrl = unauthorizedUserImgUrl;
    }
}

