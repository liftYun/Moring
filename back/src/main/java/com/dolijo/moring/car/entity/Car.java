package com.dolijo.moring.car.entity;

import com.dolijo.moring.member.entity.Member;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.Comment;

import java.time.LocalDate;

@Entity
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "car")
public class Car {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_uuid", referencedColumnName = "member_uuid", nullable = false)
    private Member member;

    @Column(name = "tokenId" , length = 60, nullable = false)
    @Comment("차대번호")
    private String vin;

    @Column(name = "registered_at", nullable = false, updatable = false) // 변경 허용 X
    @Comment("자동차 등록일")
    private LocalDate registeredAt;

    @Builder
    public Car(Member member, String vin, LocalDate registeredAt) {
        this.member = member;
        this.vin = vin;
        this.registeredAt = registeredAt;
    }
}
