package com.dolijo.moring.car.vo.out;

import lombok.Builder;
import lombok.Getter;

import java.time.LocalDate;

@Getter
@Builder
public class CarInspectionLogResponseVo {
    private final LocalDate inspectionDate;
    private final String inspectionStatus;
}
