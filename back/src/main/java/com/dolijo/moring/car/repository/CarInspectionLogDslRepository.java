package com.dolijo.moring.car.repository;

import com.dolijo.moring.car.entity.Car;
import com.dolijo.moring.car.entity.QCarInspectionLog;
import com.dolijo.moring.car.valueobject.InspectionStatus;
import com.querydsl.jpa.impl.JPAQueryFactory;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.time.LocalDateTime;

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

    /**
     * 특정 차량의 특정 점검일에 해당하는 점검 상태와 상세정보를 업데이트
     *
     * @param car 차량 엔티티
     * @param inspectionDate 점검일
     * @param status 업데이트할 점검 상태
     * @return 업데이트된 레코드 수
     */
    public long updateStatusAndDetailsByCarAndDate(Car car, LocalDate inspectionDate, InspectionStatus status) {
        return queryFactory
                .update(carInspectionLog)
                    .set(carInspectionLog.inspectionStatus, status)
                    .set(carInspectionLog.updatedAt, LocalDateTime.now()) // 업데이트 시간 설정
                .where(carInspectionLog.car.eq(car)
                    .and(carInspectionLog.inspectionDate.goe(inspectionDate))
                    .and(carInspectionLog.inspectionStatus.eq(InspectionStatus.PENDING))) // 완료상태가 되는 것은 대기 상태뿐
                .execute();
    }

    /**
     * 차량 ID로 가장 최근의 대기 중인 점검일 조회
     *
     * @param carId 차량 ID
     * @return 가장 최근의 대기 중인 점검일
     */
    public LocalDate findLatestPendingInspectionDateByCarId(Long carId) {

        return queryFactory.select(carInspectionLog.inspectionDate)
                .from(carInspectionLog)
                .where(carInspectionLog.car.id.eq(carId)
                        .and(carInspectionLog.inspectionStatus.eq(InspectionStatus.PENDING)))
                .orderBy(carInspectionLog.inspectionDate.desc())
                .limit(1)
                .fetchOne();
    }
}
