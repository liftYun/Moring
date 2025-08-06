package com.dolijo.moring.notifycation.repository;

import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.data.jpa.repository.JpaRepository;
import com.dolijo.moring.notifycation.entity.Notification;

public interface NotificationRepository extends JpaRepository<Notification, Long> {
    /**
     * 차량 ID로 읽지 않은 알림 개수 조회 (조인 없이)
     */

    @Query("select count(n) from Notification n where n.car.id = :carId and n.readFlag = false")
    long countUnreadByCarId(@Param("carId") Long carId);
}
