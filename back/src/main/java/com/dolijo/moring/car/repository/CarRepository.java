package com.dolijo.moring.car.repository;

import com.dolijo.moring.car.entity.Car;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CarRepository extends JpaRepository<Car,Long> {
}
