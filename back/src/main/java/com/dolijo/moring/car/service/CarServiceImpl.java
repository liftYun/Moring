package com.dolijo.moring.car.service;


import com.dolijo.moring.car.dto.in.RegisterCarRequestDto;
import com.dolijo.moring.car.dto.out.CarMileageLogResponseDto;
import com.dolijo.moring.car.dto.out.CarResponseDto;
import com.dolijo.moring.car.entity.Car;
import com.dolijo.moring.car.entity.CarMileageLog;
import com.dolijo.moring.car.repository.CarDslRepository;
import com.dolijo.moring.car.repository.CarMileageLogDslRepository;
import com.dolijo.moring.car.repository.CarMileageLogRepository;
import com.dolijo.moring.car.repository.CarRepository;
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
    private final CarMileageLogDslRepository carMileageLogDslRepository;

    @Override
    @Transactional
    public Long registerCar(RegisterCarRequestDto dto, String memberUuid) {
        // 1.존재하는 회원인지 확인
        Member member = memberRepository.findByUuid(memberUuid)
                .orElseThrow(() -> new BaseException(BaseResponseStatus.NO_EXIST_MEMBER));
        // 2.이미 등록한 차량인지 확인
        if (carRepository.existsByVin(dto.getVin())) {
            throw new BaseException(BaseResponseStatus.ALREADY_REGISTERED_CAR);
        }
        // 저장
        return carRepository.save(dto.from(member)).getId();
    }

    @Override
    public List<CarResponseDto> getCarsByMemberUuid(String memberUuid) {
        // 1.회원 존재 여부 확인
        Long memberId = memberRepository.findIdByMemberUuid(memberUuid)
                .orElseThrow(() -> new BaseException(BaseResponseStatus.NO_EXIST_MEMBER));
        // 조회
        return carDslRepository.findCarsResponseDtoByMemberId(memberId);
    }

    @Override
    @Transactional
    public void deleteCarByVin(String vin) {
        int deletedCount = carRepository.deleteByVin(vin);
        log.info("차량 삭제 레코드 수 : "+deletedCount);
        if (deletedCount == 0) {
            throw new BaseException(BaseResponseStatus.NO_EXIST_CAR);
        }
    }

    @Transactional
    @Override
    public Long registerCarMileage(String vin, Float mileageKm) {
        // 1. VIN으로 차량 조회
        Car car = carRepository.findByVin(vin)
                .orElseThrow(() -> new BaseException(BaseResponseStatus.NO_EXIST_CAR));

        // 2. 오늘 날짜로 이미 log가 있으면 update, 없으면 새로 생성
        // (로직은 상황에 따라 구현)
        CarMileageLog carMileageLog = carMileageLogRepository
                .findByCarIdAndRecordedDate(car.getId(), LocalDate.now())
                .orElseGet(() -> new CarMileageLog(car, LocalDate.now(), 0.0f)); // 없으면 생성


        carMileageLog.addMileage(mileageKm); // 누적
        log.info(carMileageLog);

        carMileageLogRepository.save(carMileageLog);
        return carMileageLog.getId();
    }

    @Override
    public Slice<CarMileageLogResponseDto> getLogsByVin(String vin, Pageable pageable) {
        return carMileageLogDslRepository.findLogsResponseDtoByVin(vin, pageable);

    }
}
