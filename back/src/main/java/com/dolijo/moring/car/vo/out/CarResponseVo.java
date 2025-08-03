package com.dolijo.moring.car.vo.out;

import com.dolijo.moring.car.dto.out.CarResponseDto;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public class CarResponseVo {
    private final String vin;
    private final String modelName;
    private final String nickname;

    // DTO -> VO 변환 메서드
    public static CarResponseVo from(CarResponseDto dto) {
        return CarResponseVo.builder()
                .vin(dto.getVin())
                .modelName(dto.getModelName())
                .nickname(dto.getNickname())
                .build();
    }
}
