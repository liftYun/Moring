package com.dolijo.moring.notifycation.service;

import com.dolijo.moring.car.entity.Car;
import com.dolijo.moring.car.repository.CarRepository;
import com.dolijo.moring.notifycation.repository.NotificationRepository;
import com.dolijo.moring.common.exception.BaseException;
import com.dolijo.moring.common.base.BaseResponseStatus;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class NotificationService {
    private final CarRepository carRepository;
    private final NotificationRepository notificationRepository;

    /**
     * 차량(VIN)별 읽지 않은 알림 개수 조회
     */
    @Transactional(readOnly = true)
    public long countUnreadNotificationsByCarVin(String vin) {
        Car car = carRepository.findByVin(vin)
                .orElseThrow(() -> new BaseException(BaseResponseStatus.NO_EXIST_CAR));
        return notificationRepository.countUnreadByCarId(car.getId());
    }
}
