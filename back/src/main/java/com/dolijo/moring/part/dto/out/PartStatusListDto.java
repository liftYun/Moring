package com.dolijo.moring.part.dto.out;

import com.querydsl.core.annotations.QueryProjection;
import lombok.Builder;
import lombok.Getter;
import lombok.ToString;

import java.time.LocalDateTime;

@Getter
@ToString
public class PartStatusListDto  {
    private final String nameEn; // 부품 영어이름
    private final LocalDateTime lastChange; // 마지막 교환 날짜시간
    private final Integer recommendedCycleMonths; // 권장 교체 주기(달)

    @QueryProjection
    @Builder
    public PartStatusListDto (String nameEn, LocalDateTime lastChange, Integer recommendedCycleMonths) {
        this.nameEn = nameEn;
        this.lastChange = lastChange;
        this.recommendedCycleMonths = recommendedCycleMonths;
    }
}
