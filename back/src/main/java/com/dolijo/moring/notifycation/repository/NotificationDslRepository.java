package com.dolijo.moring.notifycation.repository;

import com.dolijo.moring.notifycation.dto.out.NotificationListResponseDto;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;

public interface NotificationDslRepository {
    Slice<NotificationListResponseDto> findUnreadNotificationListByCarId(Long carId, Pageable pageable);
}

