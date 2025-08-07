package com.dolijo.moring.notifycation.repository;

import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import com.dolijo.moring.notifycation.entity.Notification;

public interface NotificationRepository extends JpaRepository<Notification, Long> {
    /**
     * 차량 ID로 읽지 않은 알림 개수 조회 (조인 없이)
     */

    @Query("select count(n) from Notification n where n.car.id = :carId and n.readFlag = false")
    long countUnreadByCarId(@Param("carId") Long carId);

    /**
     * 알림 단건 읽음 처리
     */
    @Modifying
    @Query("update Notification n set n.readFlag = true where n.id = :notificationId")
    void updateReadFlagById(@Param("notificationId") Long notificationId);

    /**
     * 차량 ID로 전체 알림 읽음 처리
     */
    @Modifying
    @Query("update Notification n set n.readFlag = true where n.car.id = :carId and n.readFlag = false")
    int updateReadFlagByCarId(@Param("carId") Long carId);
}
