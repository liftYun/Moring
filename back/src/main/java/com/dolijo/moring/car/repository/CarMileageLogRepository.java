package com.dolijo.moring.car.repository;

import com.dolijo.moring.car.entity.Car;
import com.dolijo.moring.car.entity.CarMileageLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.Optional;
@Repository
public interface CarMileageLogRepository extends JpaRepository<CarMileageLog,Long> {
    Optional<CarMileageLog> findByCarIdAndRecordedDate(Long carId, LocalDate recordedDate);
}
