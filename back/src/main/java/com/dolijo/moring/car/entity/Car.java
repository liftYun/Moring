package com.dolijo.moring.car.entity;

import com.dolijo.moring.common.base.BaseEntity;
import com.dolijo.moring.member.entity.Member;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.Comment;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;


@Entity
@AllArgsConstructor
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "car")
@Getter
public class Car extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    @Column(name = "vin" , length = 60, nullable = false, unique = true)
    @Comment("차대번호")
    private String vin;

    @Column(name = "registered_at", nullable = false, updatable = false) // 변경 허용 X
    @Comment("자동차 등록일")
    private LocalDate registeredAt;

    @Column(name = "model_name" , length = 20, nullable = false)
    @Comment("모델명(예:XM3)")
    private String modelName;

    @Column(name = "nickname" , length = 30, nullable = false)
    @Comment("차량의 애칭")
    private String nickname;


    @Builder
    public Car(Member member, String vin, LocalDate registeredAt, String modelName, String nickname) {
        this.member = member;
        this.vin = vin;
        this.registeredAt = registeredAt;
        this.modelName = modelName;
        this.nickname = nickname;
    }
}
