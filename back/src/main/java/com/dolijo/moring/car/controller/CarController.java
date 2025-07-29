package com.dolijo.moring.car.controller;

import com.dolijo.moring.car.dto.in.RequestRegisterCarDto;
import com.dolijo.moring.car.vo.in.RequestRegisterCarVo;
import com.dolijo.moring.common.base.BaseResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.enums.ParameterIn;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springdoc.core.annotations.ParameterObject;
import org.springframework.web.bind.annotation.*;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/car")
@Tag(name = "차량", description = "차량 관련 API")
@Log4j2
public class CarController {

    @Operation(summary = "차량 등록(수동)", description = "차량을 직접 수동으로 등록")
    @PostMapping("/")
    public BaseResponse<Void> registerCar(
            @Parameter(
                    in          = ParameterIn.HEADER,
                    name        = "memberUuid",
                    description = "테스트용 임시 UUID",
                    required    = true,
                    example     = "f19f7658-6b86-11f0-8ea9-ea7f6f85ec62"
            )
            @RequestHeader(value = "memberUuid", required = true, defaultValue = "f19f7658-6b86-11f0-8ea9-ea7f6f85ec62")
            String memberUuid,
            @ParameterObject RequestRegisterCarVo requestVo
    ) {
        log.info(requestVo.from());
        return BaseResponse.ok();
    }
}
