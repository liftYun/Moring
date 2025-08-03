package com.dolijo.moring.part.entity;

import com.dolijo.moring.car.entity.Car;
import com.dolijo.moring.part.entity.valueobject.PartType;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.Comment;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

import java.time.LocalDateTime;

import static jakarta.persistence.FetchType.LAZY;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(
        name = "part_change_log",
        indexes = {
                @Index(name = "idx_car_id_created_at_desc", columnList = "car_id, createdAt DESC")
        }
)
public class PartChangeLog {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    @ManyToOne(fetch = LAZY)
    @JoinColumn(name="part_id")
    private Part part;

    @ManyToOne(fetch = LAZY)
    @JoinColumn(name = "car_id")
    @OnDelete(action = OnDeleteAction.CASCADE)
    private Car car;

    @Column(updatable = false, nullable = false)
    @Comment("최초생성일")
    private LocalDateTime createdAt;

    @Builder
    public PartChangeLog(Part part, Car car, LocalDateTime createdAt) {
        this.createdAt = createdAt;
        this.part = part;
        this.car = car;
    }
}
