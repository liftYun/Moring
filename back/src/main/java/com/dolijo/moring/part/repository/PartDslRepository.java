package com.dolijo.moring.part.repository;

import com.dolijo.moring.part.dto.out.PartStatusListDto;
import com.dolijo.moring.part.dto.out.QPartStatusListDto;
import com.dolijo.moring.part.entity.Part;
import com.dolijo.moring.part.entity.QPart;
import com.dolijo.moring.part.entity.QPartChangeLog;
import com.querydsl.jpa.JPAExpressions;
import com.querydsl.jpa.impl.JPAQueryFactory;
import lombok.RequiredArgsConstructor;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

import static com.dolijo.moring.part.entity.QPart.part;
import static com.dolijo.moring.part.entity.QPartChangeLog.partChangeLog;

@Repository
@RequiredArgsConstructor
public class PartDslRepository {
    private final JPAQueryFactory queryFactory;
    private static final long LIMIT_VALUE = 20L;

    public List<PartStatusListDto> findPartStatusListByCarId(Long carId) {
        // 1. 먼저 해당 차량의 각 부품별 최신 교체 이력을 찾는 서브쿼리
        QPartChangeLog subChangeLog = new QPartChangeLog("subChangeLog");

        return queryFactory
                .select(new QPartStatusListDto(
                        part.id,
                        part.nameEn,
                        partChangeLog.createdAt,
                        part.recommendedCycleMonths
                ))
                .from(part)
                .leftJoin(partChangeLog)
                .on(partChangeLog.part.id.eq(part.id)
                        .and(partChangeLog.car.id.eq(carId))
                        .and(partChangeLog.createdAt.eq(
                                // 각 부품별 최신 교체 이력 찾기
                                JPAExpressions.select(subChangeLog.createdAt.max())
                                        .from(subChangeLog)
                                        .where(subChangeLog.part.id.eq(part.id)
                                                .and(subChangeLog.car.id.eq(carId)))
                        ))
                )
                .orderBy(part.id.asc())
                .limit(LIMIT_VALUE) // 부품 테이블 데이터 많을 만약의 경우 부하 방지
                .fetch();
    }
}
