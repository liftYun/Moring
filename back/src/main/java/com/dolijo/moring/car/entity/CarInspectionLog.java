package com.dolijo.moring.car.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.Comment;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

import java.time.LocalDate;

@Entity
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "car_inspection_log")
public class CarInspectionLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "car_id")
    @OnDelete(action = OnDeleteAction.CASCADE)
    private Car car;

    @Column(name = "last_inspection_date", nullable = false, updatable = false)
    @Comment("최근 점검일")
    private LocalDate lastInspectionDate;

    @Column(name = "inspection_expiry_date", nullable = false, updatable = false)
    @Comment("점검 만료일")
    private LocalDate inspectionExpiryDate;

    @Builder
    public CarInspectionLog(Car car, LocalDate lastInspectionDate, LocalDate inspectionExpiryDate) {
        this.car = car;
        this.lastInspectionDate = lastInspectionDate;
        this.inspectionExpiryDate = inspectionExpiryDate;
    }
}
