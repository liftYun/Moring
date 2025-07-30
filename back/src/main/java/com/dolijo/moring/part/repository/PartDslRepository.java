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

        return queryFactory
                .select(new QPartStatusListDto(
                        part.nameEn,
                        partChangeLog.createdAt,
                        part.recommendedCycleMonths
                ))
                .from(part)
                .leftJoin(partChangeLog)
                .on(partChangeLog.part.id.eq(part.id)
                        .and(partChangeLog.car.id.eq(carId))
                        .and(partChangeLog.createdAt.eq(
                                // 가장 최근 부품 교환 이력 날짜만을 조회하는 서브쿼리
                                JPAExpressions.select(partChangeLog.createdAt.max())
                                        .from(partChangeLog)
                                        .where(
                                                partChangeLog.part.id.eq(part.id),
                                                partChangeLog.car.id.eq(carId)
                                        )
                        ))
                )
                .limit(LIMIT_VALUE) // 부품 테이블 데이터 많을 만약의 경우 부하 방지
                .fetch();
    }
}
