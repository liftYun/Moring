package com.dolijo.moring.car.dto.out;

import com.querydsl.core.annotations.QueryProjection;
import lombok.AllArgsConstructor;
import lombok.Getter;

import java.time.LocalDate;

@Getter
public class CarMileageLogResponseDto {
    private Float mileageKm;
    private LocalDate recordedDate;

    @QueryProjection
    public CarMileageLogResponseDto(Float mileageKm, LocalDate recordedDate) {
        this.mileageKm = mileageKm;
        this.recordedDate = recordedDate;
    }
}
