package com.dolijo.moring.car.repository;


import com.dolijo.moring.car.dto.out.CarResponseDto;
import com.dolijo.moring.car.dto.out.QCarResponseDto;
import com.dolijo.moring.car.entity.QCar;
import com.querydsl.jpa.impl.JPAQueryFactory;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;

import java.util.List;

import static com.dolijo.moring.car.entity.QCar.car;

@Repository
@RequiredArgsConstructor
public class CarDslRepository {
    private final JPAQueryFactory queryFactory;

    public List<CarResponseDto> findCarsResponseDtoByMemberId(Long memberId) {
        return queryFactory
                .select(new QCarResponseDto(
                        car.vin, car.modelName, car.nickname
                ))
                .from(car)
                .where(car.member.id.eq(memberId))
                .fetch();
    }

}
