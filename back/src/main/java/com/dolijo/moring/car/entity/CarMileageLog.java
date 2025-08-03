package com.dolijo.moring.car.entity;

import jakarta.persistence.*;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import lombok.*;
import org.hibernate.annotations.*;

import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(
        name = "car_mileage_log",
        indexes = {
                @Index(
                        name = "idx_car_id_recorded_date_desc",
                        columnList = "car_id, recorded_date DESC"
                )
        }
)
@Getter
@DynamicUpdate
@ToString
public class CarMileageLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "car_id")
    @OnDelete(action = OnDeleteAction.CASCADE)
    private Car car;

    @Column(name = "recorded_date", nullable = false, updatable = false)
    @Comment("주행일")
    private LocalDate recordedDate;

    @Column(name = "mileage_km", columnDefinition = "DECIMAL(10,2)", nullable = false)
    @Comment("주행거리 (km)")
    private Float mileageKm;

    @Builder
    public CarMileageLog(Car car, LocalDate recordedDate, Float mileageKm) {
        this.car = car;
        this.recordedDate = recordedDate;
        this.mileageKm = mileageKm;
    }

    public void addMileage(float addKm) {
        this.mileageKm += addKm;
    }


}
