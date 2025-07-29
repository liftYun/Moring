package com.dolijo.moring.car.service;


import com.dolijo.moring.car.dto.in.RequestRegisterCarDto;
import org.springframework.transaction.annotation.Transactional;

@Transactional(readOnly = true)
public interface CarService {

    // 장바구니 아이템 추가 [상품디테일 페이지의 장바구니 추가버튼]
    @Transactional
    public void registerCar(RequestRegisterCarDto dto);



}
