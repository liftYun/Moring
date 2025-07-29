package com.dolijo.moring.car.service;


import com.dolijo.moring.car.dto.in.RequestRegisterCarDto;
import com.dolijo.moring.car.repository.CarRepository;
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
    private final MemberRepository memberRepository;

    @Override
    public void registerCar(RequestRegisterCarDto dto) {
        memberRepository.findBy
        carRepository.save(dto.from());
    }
}
