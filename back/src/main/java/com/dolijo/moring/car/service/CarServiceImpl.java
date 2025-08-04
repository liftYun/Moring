package com.dolijo.moring.car.service;


import com.dolijo.moring.car.dto.CarInspectionLogResponseDto;
import com.dolijo.moring.car.dto.in.RegisterCarRequestDto;
import com.dolijo.moring.car.dto.out.CarMileageLogResponseDto;
import com.dolijo.moring.car.dto.out.CarResponseDto;
import com.dolijo.moring.car.entity.Car;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;
import com.dolijo.moring.car.entity.CarInspectionLog;
import com.dolijo.moring.car.entity.CarMileageLog;
import com.dolijo.moring.car.repository.*;
import com.dolijo.moring.car.valueobject.InspectionStatus;
import com.dolijo.moring.common.base.BaseResponseStatus;
import com.dolijo.moring.common.exception.BaseException;
import com.dolijo.moring.member.entity.Member;
import com.dolijo.moring.member.repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

@Service
@Log4j2
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CarServiceImpl implements CarService{
    private final CarRepository carRepository;
    private final CarDslRepository  carDslRepository;
    private final MemberRepository memberRepository;
    private final CarMileageLogRepository carMileageLogRepository;
    private final CarInspectionLogQueryDslRepository carInspectionLogQueryDslRepository;
    private final CarMileageLogDslRepository carMileageLogDslRepository;
    private final CarInspectionLogRepository carInspectionLogRepository;
    private final CarInspectionLogDslRepository carInspectionLogDslRepository;

    @Override
    @Transactional
    public Long registerCar(RegisterCarRequestDto dto, String memberUuid) {
        // 1.존재하는 회원인지 확인
        Member member = memberRepository.findByUuid(memberUuid)
                .orElseThrow(() -> new BaseException(BaseResponseStatus.NO_EXIST_MEMBER));
        // 2.이미 등록한 차량인지 확인 후 차량 저장
        if (carRepository.existsByVin(dto.getVin())) {
            throw new BaseException(BaseResponseStatus.ALREADY_REGISTERED_CAR);
        }
        Car newCar = dto.from(member); // 등록차량 생성
        carRepository.save(newCar); // 차량 저장

        // 3. 차량 등록일 + 4 년으로 carInspectionLog 생성
        LocalDate inspectionDate = dto.getRegisteredAt().plusYears(4);
        CarInspectionLog inspectionLog = CarInspectionLog.builder()
                .car(newCar)
                .inspectionDate(inspectionDate)
                .inspectionStatus(InspectionStatus.PENDING) // 초기 상태는 PENDING
                .build();
        carInspectionLogRepository.save(inspectionLog); // 점검 로그 저장
        // 저장
        return newCar.getId();
    }

    public List<CarResponseDto> getCarsByMemberUuid(String memberUuid) {
        // 1.회원 존재 여부 확인
        Long memberId = memberRepository.findIdByMemberUuid(memberUuid)
                .orElseThrow(() -> new BaseException(BaseResponseStatus.NO_EXIST_MEMBER));
        // 조회
        return carDslRepository.findCarsResponseDtoByMemberId(memberId);
    }

    @Override
    @Transactional
    public void deleteCarByVin(String carVin) {
        // 차량 삭제 (삭제된 레코드 수 반환)
        long deletedCount = carRepository.deleteByVin(carVin);
        log.info("차량 삭제 레코드 수 : " + deletedCount);
        if (deletedCount == 0) {
            throw new BaseException(BaseResponseStatus.NO_EXIST_CAR);
        }
    }

    @Transactional
    @Override
    public Long registerCarMileage(String carVin, Float mileageKm) {
        // 1. VIN으로 차량 조회
        Car car = carRepository.findByVin(carVin)
                .orElseThrow(() -> new BaseException(BaseResponseStatus.NO_EXIST_CAR));

        // 2. 오늘 날짜로 이미 log가 있으면 update, 없으면 새로 생성
        CarMileageLog carMileageLog = carMileageLogRepository.findByCarIdAndRecordedDate(car.getId(), LocalDate.now())
                .orElseGet(() -> CarMileageLog.builder()
                        .car(car)
                        .recordedDate(LocalDate.now())
                        .mileageKm(0f)
                        .build());

        carMileageLog.addMileage(mileageKm); // 누적
        log.info(carMileageLog);

        carMileageLogRepository.save(carMileageLog);
        return carMileageLog.getId();
    }

    @Override
    public Slice<CarMileageLogResponseDto> getLogsByVin(String vin, Pageable pageable) {
        return carMileageLogDslRepository.findLogsResponseDtoByVin(vin, pageable);

    }

    @Override
    @Transactional
    public void registerCarInspection(String vin, String inspectionDate) {
        // 1. 차량 존재 여부 확인
        Car car = carRepository.findByVin(vin)
                .orElseThrow(() -> new BaseException(BaseResponseStatus.NO_EXIST_CAR));
        
        LocalDate today = LocalDate.parse(inspectionDate);
        
        // 2. 해당 점검일에 대한 기존 점검 로그 상태를 COMPLETED로 업데이트
        long updatedCount = carInspectionLogDslRepository.updateStatusByCarAndDate(car, today, InspectionStatus.COMPLETED);
        
        // 3. 업데이트된 레코드가 정확히 1개인지 확인
        if (updatedCount == 0) {
            throw new BaseException(BaseResponseStatus.NO_EXIST_INSPECTION_LOG);
        } else if (updatedCount > 1) {
            log.error("차량 ID: {}, 점검일: {}에 대해 여러 개의 점검 기록이 업데이트됨", car.getId(), today);
            throw new BaseException(BaseResponseStatus.INTERNAL_SERVER_ERROR);
        }
        
        // 4. 다음 점검일(+2년)로 새로운 PENDING 점검 로그 생성
        LocalDate nextInspectionDate = today.plusYears(2);
        CarInspectionLog nextInspectionLog = CarInspectionLog.builder()
                .car(car)
                .inspectionDate(nextInspectionDate)
                .inspectionStatus(InspectionStatus.PENDING)
                .build();
        
        carInspectionLogRepository.save(nextInspectionLog);

        log.info("차량 점검 완료 처리 - VIN: {}, 점검일: {}, 다음 점검일: {}", vin, today, nextInspectionDate);
    }

    @Override
    public Slice<CarInspectionLogResponseDto> getCarInspectionLogs(String vin, Pageable pageable) {
        return carInspectionLogQueryDslRepository.findInspectionLogsResponseDtoByVin(vin, pageable);
    }
}
