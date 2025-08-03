package com.dolijo.moring.car.repository;

import com.dolijo.moring.car.entity.Car;
import com.dolijo.moring.car.valueobject.InspectionStatus;
import com.querydsl.jpa.impl.JPAQueryFactory;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;

import static com.dolijo.moring.car.entity.QCarInspectionLog.carInspectionLog;

@Repository
@RequiredArgsConstructor
public class CarInspectionLogDslRepository {
    private final JPAQueryFactory queryFactory;

    /**
     * 특정 차량의 특정 점검일에 해당하는 점검 상태를 업데이트
     *
     * @param car 차량 엔티티
     * @param inspectionDate 점검일
     * @param status 업데이트할 점검 상태
     * @return 업데이트된 레코드 수
     */
    public long updateStatusByCarAndDate(Car car, LocalDate inspectionDate, InspectionStatus status) {
        return queryFactory.update(carInspectionLog)
                .set(carInspectionLog.inspectionStatus, status)
                .where(carInspectionLog.car.eq(car)
                        .and(carInspectionLog.inspectionDate.goe(inspectionDate)) // 점검일 데드라인 >= 실제 점검일
                        .and(carInspectionLog.inspectionStatus.eq(InspectionStatus.PENDING)))
                .execute();
    }
}
