package com.dolijo.moring.car.controller;

import com.dolijo.moring.car.dto.in.RegisterCarRequestDto;
import com.dolijo.moring.car.dto.out.CarMileageLogResponseDto;
import com.dolijo.moring.car.dto.out.CarResponseDto;
import com.dolijo.moring.car.service.CarService;
import com.dolijo.moring.car.vo.in.RegisterCarRequestVo;
import com.dolijo.moring.car.vo.out.CarResponseVo;
import com.dolijo.moring.common.base.BaseResponse;
import com.dolijo.moring.common.base.BaseResponseStatus;
import com.dolijo.moring.common.exception.BaseException;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.enums.ParameterIn;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springdoc.core.annotations.ParameterObject;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/cars")
@Tag(name = "차량", description = "차량 관련 API")
@Log4j2
public class CarController {
    private final CarService carService;

    @Operation(summary = "회원의 차량 등록",   description = """
        회원이 직접 차량 정보를 수동으로 등록합니다.

        - 차량 VIN(차대번호), 모델명, 애칭, 등록일 등을 입력받아 저장합니다.
        - 등록된 VIN이 이미 존재하면 중복 등록을 방지하기 위해 예외를 발생시킵니다.
        """)
    @PostMapping("/")
    public BaseResponse<Long> registerCar(
            @Parameter(
                    name        = "memberUuid",
                    description = "테스트용 임시 UUID",
                    required    = true,
                    example     = "f19f7658-6b86-11f0-8ea9-ea7f6f85ec62"
            )
            @RequestHeader(value = "memberUuid", required = true, defaultValue = "f19f7658-6b86-11f0-8ea9-ea7f6f85ec62")
            String memberUuid,
            @ParameterObject RegisterCarRequestVo requestVo
    ) {
            return  BaseResponse.of(carService.registerCar(requestVo.toDto(),memberUuid));
    }

    @Operation(summary = "회원의 등록 차량 리스트 조회",   description = """
        회원이 등록한 차량들을 조회.

        - 헤더의 회원 uuid와 url에 요청하는 회원의 uuid가 다르면 에러
        """)
    @GetMapping("/{memberUuid}/list")
    public BaseResponse<List<CarResponseVo>> getCarsByMemberUuid(
            @Parameter(description = "조회 대상 회원 UUID", required = true, example = "f19f7658-6b86-11f0-8ea9-ea7f6f85ec62")
            @PathVariable String memberUuid,

            @Parameter(description = "인증된 사용자 UUID", required = true, example = "f19f7658-6b86-11f0-8ea9-ea7f6f85ec62")
            @RequestHeader("memberUuid") String authenticatedUuid
    ) {
        // 본인 아니면 에러
        if (!memberUuid.equals(authenticatedUuid)) {
            throw new BaseException(BaseResponseStatus.DISALLOWED_ACTION);
        }
        List<CarResponseDto> dtoList = carService.getCarsByMemberUuid(memberUuid);

        return BaseResponse.of(
                dtoList.stream()
                        .map(CarResponseVo::from)
                        .toList()
        );
    }


    @Operation(summary = "회원의 등록 차량 단건 삭제", description = "VIN(차대번호)을 기준으로 차량 정보를 삭제합니다.")
    @DeleteMapping("/{vin}")
    public BaseResponse<Void> deleteCarByVin(
            @Parameter(description = "차량 VIN", required = true, example = "KNMK5C2HMLP000437")
            @PathVariable String vin) {
        carService.deleteCarByVin(vin);
        return BaseResponse.ok();
    }



    @Operation(summary = "차량 이동거리 등록", description = "차량 VIN과 누적 km를 경로 변수로 받아 이동거리를 등록합니다.")
    @PostMapping("/{vin}/{km}")
    public BaseResponse<Void> registerCarMileage(
            @Parameter(description = "차량 VIN", required = true, example = "KNMK5C2HMLP000437") @PathVariable String vin,
            @Parameter(description = "누적 km", required = true, example = "12.0") @PathVariable Float km
    ) {
       carService.registerCarMileage(vin, km);
        return BaseResponse.ok();
    }
    
    @Operation(summary = "차량 이동거리 조회", description = "내려서 더보기 하는 방식 (페이지네이션)")
    @GetMapping("/{vin}/mileage-logs-paging")
    public BaseResponse<Slice<CarMileageLogResponseDto>> getMileageLogs(
            @Parameter(description = "차량 VIN", required = true, example = "KNMK5C2HMLP000437")
            @PathVariable String vin,
            @ParameterObject Pageable pageable
    ) {
        Slice<CarMileageLogResponseDto> result = carService.getLogsByVin(vin, pageable);
        return BaseResponse.of(result);
    }
    
    // 차량 정기점검 등록  
    @Operation(summary = "차량 정기점검 등록", description = "차량 VIN과 점검일을 받아 정기점검을 등록합니다. 상태는 서버에서 PENDING으로 고정됩니다.")
    @PostMapping("/{vin}/inspection")
    public BaseResponse<Void> registerCarInspection(
            @Parameter(description = "차량 VIN", required = true, example = "KNMK5C2HMLP000437") @PathVariable String vin,
            @Parameter(description = "점검일 (YYYY-MM-DD)", required = true, example = "2025-01-01") @RequestParam String inspectionDate
    ) {
        carService.registerCarInspection(vin, inspectionDate);
        return BaseResponse.ok();
    }




}
