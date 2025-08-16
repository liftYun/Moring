package com.dolijo.moring.car.service;


import com.dolijo.moring.car.dto.CarInspectionLogResponseDto;
import com.dolijo.moring.car.dto.in.RegisterCarInspectionDto;
import com.dolijo.moring.car.dto.in.RegisterCarRequestDto;
import com.dolijo.moring.car.dto.out.CarMileageLogResponseDto;
import com.dolijo.moring.car.dto.out.CarResponseDto;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

public interface CarService {

     Long registerCar(RegisterCarRequestDto dto, String memberUuid);

     List<CarResponseDto> getCarsByMemberUuid(String memberUuid);

     void deleteCarByVin(String vin);

     public Long registerCarMileage(String vin, Float mileageKm);

     public Slice<CarMileageLogResponseDto> getLogsByVin(String vin, Pageable pageable);

     void registerCarInspection(String vin, RegisterCarInspectionDto dto);

     Slice<CarInspectionLogResponseDto> getCarInspectionLogs(String vin, Pageable pageable);

     LocalDate getLatestPendingInspectionDate(String vin);

     void updateUnauthorizedDriverPopup(String vin, boolean isAgreed);


}
