package com.dolijo.moring.car.repository;

import com.dolijo.moring.car.dto.CarInspectionLogResponseDto;
import com.dolijo.moring.car.dto.QCarInspectionLogResponseDto;
import com.dolijo.moring.car.valueobject.InspectionStatus;
import com.querydsl.jpa.impl.JPAQueryFactory;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.data.domain.SliceImpl;
import org.springframework.stereotype.Repository;

import java.util.List;

import static com.dolijo.moring.car.entity.QCar.car;
import static com.dolijo.moring.car.entity.QCarInspectionLog.carInspectionLog;

@Repository
@RequiredArgsConstructor
public class CarInspectionLogQueryDslRepository {

    private final JPAQueryFactory queryFactory;

    public Slice<CarInspectionLogResponseDto> findInspectionLogsResponseDtoByVin(String vin, Pageable pageable) {
        List<CarInspectionLogResponseDto> fetch = queryFactory
                .select(new QCarInspectionLogResponseDto(
                        carInspectionLog.updatedAt, // 대기에서 완료로 변경된 시점
                        carInspectionLog.inspectionStatus
                ))
                .from(carInspectionLog)
                .join(carInspectionLog.car, car)
                .where(
                        car.vin.eq(vin)
                        .and(carInspectionLog.inspectionStatus.in(
                                InspectionStatus.COMPLETED,
                                InspectionStatus.EXPIRED
                            ))
                )
                .orderBy(carInspectionLog.createdAt.desc()) // createdAt 기준 내림차순
                .offset(pageable.getOffset())
                .fetch();

        boolean hasNext = fetch.size() > pageable.getPageSize();
        if (hasNext) {
            fetch.remove(fetch.size() - 1);
        }

        return new SliceImpl<>(fetch, pageable, hasNext);
    }
}
