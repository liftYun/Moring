package com.dolijo.moring.car.controller;

import com.dolijo.moring.car.dto.CarInspectionLogResponseDto;
import com.dolijo.moring.car.dto.out.CarMileageLogResponseDto;
import com.dolijo.moring.car.dto.out.CarResponseDto;
import com.dolijo.moring.car.service.CarService;
import com.dolijo.moring.car.vo.in.RegisterCarRequestVo;
import com.dolijo.moring.car.vo.in.RegisterCarInspectionVo;
import com.dolijo.moring.car.vo.out.CarInspectionLogResponseVo;
import com.dolijo.moring.car.vo.out.CarResponseVo;
import com.dolijo.moring.common.base.BaseResponse;

import com.dolijo.moring.security.dto.out.CustomMemberDetails;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springdoc.core.annotations.ParameterObject;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
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
//            @RequestHeader(value = "memberUuid", required = true, defaultValue = "f19f7658-6b86-11f0-8ea9-ea7f6f85ec62") String memberUuid,
            @AuthenticationPrincipal CustomMemberDetails customMemberDetails,
            @RequestBody RegisterCarRequestVo requestVo
    ) {
        return  BaseResponse.of(carService.registerCar(requestVo.toDto(),customMemberDetails.getUserUuid()));
    }

    @Operation(summary = "회원의 등록 차량 리스트 조회",   description = """
        회원이 등록한 차량들을 조회.

        - 헤더의 회원 uuid와 url에 요청하는 회원의 uuid가 다르면 에러
        """)
    @GetMapping("/{memberUuid}/list")
    public BaseResponse<List<CarResponseVo>> getCarsByMemberUuid(
            @AuthenticationPrincipal CustomMemberDetails customMemberDetails
    ) {
        List<CarResponseDto> dtoList = carService.getCarsByMemberUuid(customMemberDetails.getUserUuid());

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
            @PathVariable("vin") String vin) {
        carService.deleteCarByVin(vin);
        return BaseResponse.ok();
    }



    @Operation(summary = "차량 이동거리 등록", description = "차량 VIN과 누적 km를 경로 변수로 받아 이동거리를 등록합니다.")
    @PostMapping("/{vin}/{km}")
    public BaseResponse<Void> registerCarMileage(
            @Parameter(description = "차량 VIN", required = true, example = "KNMK5C2HMLP000437") @PathVariable("vin") String vin,
            @Parameter(description = "누적 km", required = true, example = "12.0") @PathVariable("km") Float km
    ) {
       carService.registerCarMileage(vin, km);
        return BaseResponse.ok();
    }
    
    @Operation(summary = "차량 이동거리 조회", description = "내려서 더보기 하는 방식 (페이지네이션)")
    @GetMapping("/{vin}/mileage-logs-paging")
    public BaseResponse<Slice<CarMileageLogResponseDto>> getMileageLogs(
            @Parameter(description = "차량 VIN", required = true, example = "KNMK5C2HMLP000437")
            @PathVariable("vin") String vin,
            @ParameterObject Pageable pageable
    ) {
        Slice<CarMileageLogResponseDto> result = carService.getLogsByVin(vin, pageable);
        return BaseResponse.of(result);
    }
    
    // 차량 정기점검 등록
    @Operation(summary = "차량 정기점검 등록", description = "차량 VIN과 점검일, 점검 상세정보(부적합, 시정권고, 자기진단, 특기사항)를 받아 정기점검을 등록합니다. 상태는 서버에서 PENDING으로 고정됩니다.")
    @PostMapping("/{vin}/inspection")
    public BaseResponse<Void> registerCarInspection(
            @Parameter(description = "차량 VIN", required = true, example = "KNMK5C2HMLP000437")
            @PathVariable("vin") String vin,
            @RequestBody RegisterCarInspectionVo requestVo
    ) {
        carService.registerCarInspection(vin, requestVo.toDto());
        return BaseResponse.ok();
    }

    @Operation(summary = "차량 정기점검 로그 조회(과거)", description = "차량 VIN으로 정기점검 로그를 페이징 조회. \n  완료 혹은 만료된 기록만 조회됩니다.")
    @GetMapping("/{vin}/inspection-logs-paging")
    public BaseResponse<Slice<CarInspectionLogResponseVo>> getCarInspectionLogs(
            @Parameter(description = "차량 VIN", required = true, example = "KNMK5C2HMLP000437")
            @PathVariable("vin") String vin,
            @ParameterObject Pageable pageable
    ) {
        Slice<CarInspectionLogResponseDto> dtoSlice = carService.getCarInspectionLogs(vin, pageable);
        Slice<CarInspectionLogResponseVo> voSlice = dtoSlice.map(CarInspectionLogResponseDto::toVo);
        return BaseResponse.of(voSlice);
    }

    @Operation(summary = "차량의 가장 최근 PENDING 점검일 조회", description = "차량 VIN으로 예정된 정기점검의 가장 최근 날짜를 조회합니다. \n 만약 예정된 점검이 없다면 null을 반환합니다.")
    @GetMapping("/{vin}/latest-pending-inspection-date")
    public BaseResponse<LocalDate> getLatestPendingInspectionDate(
            @Parameter(description = "차량 VIN", required = true, example = "KNMK5C2HMLP000437")
            @PathVariable("vin") String vin
    ) {
        return BaseResponse.of(carService.getLatestPendingInspectionDate(vin));
    }

    @Operation(summary = "비인가 운전자 확인 모달 팝업 정보 업데이트", description = """
        비인가 운전자가 차량을 운전할 때 팝업으로 보여줄 정보를 업데이트합니다.
        - 해당 API 리턴 결과가 true 면 정상 업데이트 된 것이고, false면 제한시간안에 클라이언트 측에서 예 또는 아니오를 누르지 못한 것입니다.
        - 차량 VIN과 팝업 표시 여부를 받아 업데이트합니다.
        - 팝업 표시 여부가 true이면 차주가 인가한 것이고 false으로 인가하지 않은 무단 운전자 입니다.
        """)
    @PatchMapping("/{vin}/unauthorized-driver-popup")
    public BaseResponse<Void> updateUnauthorizedDriverPopup(
            @Parameter(description = "차량 VIN", required = true, example = "KNMK5C2HMLP000437")
            @PathVariable("vin") String vin,
            @RequestParam("showPopup") boolean isAgreed
    ) {
        carService.updateUnauthorizedDriverPopup(vin, isAgreed);
        return BaseResponse.ok();
    }






}
