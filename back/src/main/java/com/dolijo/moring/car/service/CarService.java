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

import java.util.List;

public interface CarService {

    // 장바구니 아이템 추가 [상품디테일 페이지의 장바구니 추가버튼]

    public Long registerCar(RegisterCarRequestDto dto, String memberUuid);

    public List<CarResponseDto> getCarsByMemberUuid(String memberUuid);


    public void deleteCarByVin(String vin);

    public Long registerCarMileage(String vin, Float mileageKm);

    public Slice<CarMileageLogResponseDto> getLogsByVin(String vin, Pageable pageable);

    void registerCarInspection(String vin, RegisterCarInspectionDto dto);

    Slice<CarInspectionLogResponseDto> getCarInspectionLogs(String vin, Pageable pageable);
}
