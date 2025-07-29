package com.dolijo.moring.car.dto.out;

import com.querydsl.core.annotations.QueryProjection;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Builder
@NoArgsConstructor
public class CarResponseDto {
    private String vin;
    private String modelName;
    private String nickname;

    @QueryProjection
    public CarResponseDto(String vin, String modelName, String nickname) {
        this.vin = vin;
        this.modelName = modelName;
        this.nickname = nickname;
    }
}
