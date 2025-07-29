package com.dolijo.moring.part.entity;

import com.dolijo.moring.car.entity.Car;
import com.dolijo.moring.part.entity.valueobject.PartType;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.Comment;

import java.time.LocalDateTime;

import static jakarta.persistence.FetchType.LAZY;

@Entity
@Getter
@AllArgsConstructor
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "part_change_log")
public class PartChangeLog {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    @ManyToOne(fetch = LAZY)
    @JoinColumn(name="part_id")
    private Part part;

    @ManyToOne(fetch = LAZY)
    @JoinColumn(name = "car_vin", referencedColumnName = "vin", nullable = false)
    private Car car;

    @Column(updatable = false)
    @Comment("최초생성일")
    private LocalDateTime createdAt;


}
