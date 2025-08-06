package com.dolijo.moring.notifycation.service;

import com.dolijo.moring.car.entity.Car;
import com.dolijo.moring.car.repository.CarRepository;
import com.dolijo.moring.notifycation.dto.out.NotificationListResponseDto;
import com.dolijo.moring.notifycation.repository.NotificationDslRepository;
import com.dolijo.moring.notifycation.repository.NotificationRepository;
import com.dolijo.moring.common.exception.BaseException;
import com.dolijo.moring.common.base.BaseResponseStatus;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class NotificationService {
    private final CarRepository carRepository;
    private final NotificationRepository notificationRepository;
    private final NotificationDslRepository notificationDslRepository;

    /**
     * 차량(VIN)별 읽지 않은 알림 개수 조회
     */
    @Transactional(readOnly = true)
    public long countUnreadNotificationsByCarVin(String vin) {
        Car car = carRepository.findByVin(vin)
                .orElseThrow(() -> new BaseException(BaseResponseStatus.NO_EXIST_CAR));
        return notificationRepository.countUnreadByCarId(car.getId());
    }

    /**
     * 차량별 읽지 않은 알림 리스트 조회 (페이지네이션)
     */
    public Slice<NotificationListResponseDto> getUnreadNotificationListByCarVin(String vin, Pageable pageable) {
        Car car = carRepository.findByVin(vin)
                .orElseThrow(() -> new BaseException(BaseResponseStatus.NO_EXIST_CAR));
        return notificationDslRepository.findUnreadNotificationListByCarId(car.getId(), pageable);
    }

    /**
     * 알림 단건 읽음 처리
     */
    @Transactional
    public void readNotification(Long notificationId) {
        notificationRepository.updateReadFlagById(notificationId);
    }

    /**
     * 차량(VIN)별 전체 알림 읽음 처리
     */
    @Transactional
    public long readAllNotificationsByVin(String vin) {
        Car car = carRepository.findByVin(vin)
                .orElseThrow(() -> new BaseException(BaseResponseStatus.NO_EXIST_CAR));
        return notificationRepository.updateReadFlagByCarId(car.getId());
    }
}
