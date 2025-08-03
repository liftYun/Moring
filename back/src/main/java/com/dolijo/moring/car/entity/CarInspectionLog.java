package com.dolijo.moring.car.entity;

import com.dolijo.moring.car.valueobject.InspectionStatus;
import com.dolijo.moring.car.entity.Car;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.Comment;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "car_inspection_log")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor
public class CarInspectionLog {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "car_id", nullable = false)
    private Car car;

    @Column(name = "inspection_date", nullable = false)
    @Comment("점검일 또는 예정일")
    private LocalDate inspectionDate;

    @Enumerated(EnumType.STRING)
    @Column(name = "inspection_status", nullable = false)
    @Comment("점검 상태")
    private InspectionStatus inspectionStatus;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt = java.time.LocalDateTime.now();

    @Builder
    public CarInspectionLog(Car car, LocalDate inspectionDate, InspectionStatus inspectionStatus) {
        this.car = car;
        this.inspectionDate = inspectionDate;
        this.inspectionStatus = inspectionStatus;
        this.createdAt = LocalDateTime.now();
    }
}
