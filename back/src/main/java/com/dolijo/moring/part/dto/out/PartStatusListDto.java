package com.dolijo.moring.part.dto.out;

import com.querydsl.core.annotations.QueryProjection;
import lombok.Builder;
import lombok.Getter;
import lombok.ToString;

import java.time.LocalDateTime;

@Getter
@ToString
public class PartStatusListDto  {
    private  Long partId; // 부품 ID
    private  String nameEn; // 부품 영어이름
    private  LocalDateTime lastChange; // 마지막 교환 날짜시간
    private  Integer recommendedCycleMonths; // 권장 교체 주기(달)

    @QueryProjection
    @Builder
    public PartStatusListDto(Long partId, String nameEn, LocalDateTime lastChange, Integer recommendedCycleMonths) {
        this.partId = partId;
        this.nameEn = nameEn;
        this.lastChange = lastChange;
        this.recommendedCycleMonths = recommendedCycleMonths;
    }
}
