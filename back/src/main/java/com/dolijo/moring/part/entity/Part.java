package com.dolijo.moring.part.entity;

import com.dolijo.moring.part.entity.valueobject.PartType;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.Comment;

@Entity
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Table(name = "part")
public class Part {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    @Column(name = "name", length = 30, nullable = false)
    @Comment("부품명")
    private String name;

    @Column(name = "recommended_cycle_months", nullable = false)
    @Comment("권장교체주기 (월단위)")
    private int recommendedCycleMonths;

    @Column(name = "recommended_cycle_km")
    @Comment("권장교체주기 (km단위)")
    private int recommendedCycleKm;

    @Enumerated(EnumType.STRING)
    @Column(name = "type", nullable = false)
    @Comment("부품 유형 (소모품, 장비, 기타)")
    private PartType type;

    @Column(name = "description", columnDefinition = "TEXT")
    @Comment("부품 설명")
    private String description;

    @Builder
    public Part(String name, int recommendedCycleMonths, int recommendedCycleKm, PartType type, String description) {
        this.name = name;
        this.recommendedCycleMonths = recommendedCycleMonths;
        this.recommendedCycleKm = recommendedCycleKm;
        this.type = type;
        this.description = description;
    }
}
