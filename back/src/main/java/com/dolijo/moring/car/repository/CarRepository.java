package com.dolijo.moring.car.repository;

import com.dolijo.moring.car.entity.Car;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface CarRepository extends JpaRepository<Car,Long> {
    boolean existsByVin(String vin);

    @Modifying
    @Query("DELETE FROM Car c WHERE c.vin = :vin")
    int deleteByVin(@Param("vin") String vin);

    Optional<Car> findByVin(String carVin);


}
