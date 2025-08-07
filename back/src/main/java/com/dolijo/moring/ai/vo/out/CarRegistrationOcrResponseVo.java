package com.dolijo.moring.ai.vo.out;

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
@Schema(description = "차량 등록증 OCR 응답 VO")
public class CarRegistrationOcrResponseVo {
    private final String vin; // 차량 식별 번호
    private final String modelName; // 모델명 ex) XM5
    private final LocalDate registeredAt; // 등록일 ex) 2023-01-01

}
