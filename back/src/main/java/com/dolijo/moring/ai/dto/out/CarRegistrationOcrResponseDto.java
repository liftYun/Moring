package com.dolijo.moring.ai.dto.out;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.ToString;

import java.time.LocalDate;

@Getter
@AllArgsConstructor
@Builder
@ToString
public class CarRegistrationOcrResponseDto {
    private final String vin; // 차량 식별 번호
    private final String modelName; // 모델명 ex) XM5
    private final LocalDate registeredAt; // 등록일 ex) 2023-01-01

}
