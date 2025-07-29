package com.dolijo.moring.car.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.ColumnDefault;
import org.hibernate.annotations.Comment;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "car_mileage_log")
public class CarMileageLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "car_id")
    private Car car;

    @Column(name = "recorded_date", nullable = false, updatable = false)
    @Comment("주행일")
    private LocalDate recordedDate;

    @Column(name = "mileage_km", columnDefinition = "DECIMAL(10,2)", nullable = false, updatable = false)
    @Comment("주행거리 (km)")
    @ColumnDefault("0.00")
    private Float mileageKm;

    @Builder
    public CarMileageLog(Car car, LocalDate recordedDate, Float mileageKm) {
        this.car = car;
        this.recordedDate = recordedDate;
        this.mileageKm = mileageKm;
    }
}
