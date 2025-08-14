package com.dolijo.moring.car.dto.in;

import lombok.Builder;
import lombok.Getter;
import java.time.LocalDate;

@Getter
@Builder
public class RegisterCarInspectionDto {
    private  LocalDate inspectionDate;
}
