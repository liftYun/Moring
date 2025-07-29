package com.dolijo.moring.car.service;


import com.dolijo.moring.car.dto.in.RegisterCarRequestDto;
import com.dolijo.moring.car.dto.out.CarResponseDto;
import com.dolijo.moring.car.entity.Car;
import com.dolijo.moring.car.repository.CarDslRepository;
import com.dolijo.moring.car.repository.CarRepository;
import com.dolijo.moring.common.base.BaseResponseStatus;
import com.dolijo.moring.common.exception.BaseException;
import com.dolijo.moring.member.entity.Member;
import com.dolijo.moring.member.repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@Log4j2
@RequiredArgsConstructor
public class CarServiceImpl implements CarService{
    private final CarRepository carRepository;
    private final CarDslRepository  carDslRepository;
    private final MemberRepository memberRepository;

    @Override
    public Long registerCar(RegisterCarRequestDto dto, String memberUuid) {
        // 1.존재하는 회원인지 확인
        Member member = memberRepository.findByMemberUuid(memberUuid)
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
        Member member = memberRepository.findByMemberUuid(memberUuid)
                .orElseThrow(() -> new BaseException(BaseResponseStatus.NO_EXIST_MEMBER));

        return carDslRepository.findCarsByMemberUuid(memberUuid);
    }

    @Override
    public void deleteCarByVin(String vin) {
        int deletedCount = carRepository.deleteByVin(vin);
        log.info("차량 삭제 레코드 수 : "+deletedCount);
        if (deletedCount == 0) {
            throw new BaseException(BaseResponseStatus.NO_EXIST_CAR);
        }
    }
}
