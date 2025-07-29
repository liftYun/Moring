package com.dolijo.moring.car.dto.in;

import com.dolijo.moring.car.entity.Car;
import com.fasterxml.jackson.annotation.JsonFormat;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.ToString;

import java.time.LocalDate;

@Getter
@AllArgsConstructor
@Builder
@ToString
public class RequestRegisterCarDto {
    private String vin; // 차대번호

    private String modelName; // 모델명

    private LocalDate registeredAt;  // 등록일

    public Car from() {
        return Car.builder().member().build();


    }
}
