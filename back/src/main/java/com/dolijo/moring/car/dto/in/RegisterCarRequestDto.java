package com.dolijo.moring.car.dto.in;

import com.dolijo.moring.car.entity.Car;
import com.dolijo.moring.member.entity.Member;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.ToString;

import java.time.LocalDate;

@Getter
@AllArgsConstructor
@Builder
@ToString
public class RegisterCarRequestDto {
    private String vin; // 차대번호

    private String modelName; // 모델명

    private String nickname; // 애칭

    private LocalDate registeredAt;  // 등록일

    public Car from(Member member) {
        return Car.builder()
                .member(member)
                .vin(this.vin)
                .registeredAt(this.registeredAt)
                .nickname(this.nickname)
                .modelName(this.modelName)
                .build();
    }
}
