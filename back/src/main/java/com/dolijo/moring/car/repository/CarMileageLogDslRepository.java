package com.dolijo.moring.car.repository;

import com.dolijo.moring.car.dto.out.CarMileageLogResponseDto;
import com.dolijo.moring.car.dto.out.QCarMileageLogResponseDto;
import com.dolijo.moring.car.entity.QCar;
import com.dolijo.moring.car.entity.QCarMileageLog;
import com.querydsl.jpa.impl.JPAQueryFactory;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.data.domain.SliceImpl;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
@RequiredArgsConstructor
public class CarMileageLogDslRepository {

    private final JPAQueryFactory queryFactory;

    public Slice<CarMileageLogResponseDto> findLogsResponseDtoByVin(String vin, Pageable pageable) {
        QCarMileageLog log = QCarMileageLog.carMileageLog;
        QCar car = QCar.car;

        List<CarMileageLogResponseDto> fetch = queryFactory
                .select(new QCarMileageLogResponseDto(
                        log.mileageKm,
                        log.recordedDate
                ))
                .from(log)
                .join(log.car, car)
                .where(car.vin.eq(vin))
                .orderBy(log.recordedDate.desc()) // 정렬조건 필요시
                .offset(pageable.getOffset())
                .limit(pageable.getPageSize() + 1) // 다음 페이지가 있는지 확인
                .fetch();

        boolean hasNext = fetch.size() > pageable.getPageSize();
        if (hasNext) {
            fetch.remove(fetch.size() - 1);
        }

        return new SliceImpl<>(fetch, pageable, hasNext);
    }
}