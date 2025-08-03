package com.dolijo.moring.car.repository;

import com.dolijo.moring.car.entity.CarInspectionLog;
import com.dolijo.moring.car.entity.CarMileageLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.Optional;

@Repository
public interface CarInspectionLogRepository extends JpaRepository<CarInspectionLog,Long> {
}
