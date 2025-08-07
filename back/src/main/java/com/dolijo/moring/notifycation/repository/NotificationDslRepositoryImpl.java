package com.dolijo.moring.notifycation.repository;

import com.dolijo.moring.notifycation.dto.out.NotificationListResponseDto;
import com.dolijo.moring.notifycation.entity.QNotification;
import com.querydsl.core.types.Projections;
import com.querydsl.jpa.impl.JPAQueryFactory;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.data.domain.SliceImpl;
import org.springframework.stereotype.Repository;

import lombok.RequiredArgsConstructor;
import java.util.List;

@Repository
@RequiredArgsConstructor
public class NotificationDslRepositoryImpl implements NotificationDslRepository {
    private final JPAQueryFactory queryFactory;

    @Override
    public Slice<NotificationListResponseDto> findUnreadNotificationListByCarId(Long carId, Pageable pageable) {
        QNotification notification = QNotification.notification;

        List<NotificationListResponseDto> content = queryFactory
                .select(Projections.constructor(NotificationListResponseDto.class,
                        notification.id,
                        notification.notificationDetail,
                        notification.createdAt,
                        notification.message
                ))
                .from(notification)
                .where(
                        notification.car.id.eq(carId),
                        notification.readFlag.eq(false)
                )
                .orderBy(notification.createdAt.desc())
                .offset(pageable.getOffset())
                .limit(pageable.getPageSize() + 1)
                .fetch();

        boolean hasNext = content.size() > pageable.getPageSize();
        if (hasNext) {
            content.remove(pageable.getPageSize());
        }
        return new SliceImpl<>(content, pageable, hasNext);
    }
}

