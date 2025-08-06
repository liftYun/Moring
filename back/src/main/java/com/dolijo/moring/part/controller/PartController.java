package com.dolijo.moring.part.controller;


import com.dolijo.moring.common.base.BaseResponse;
import com.dolijo.moring.part.dto.out.PartResponseDto;
import com.dolijo.moring.part.dto.out.PartStatusListResponseDto;
import com.dolijo.moring.part.service.PartService;
import com.dolijo.moring.part.vo.in.RegisterPartChangeLogRequestVo;
import com.dolijo.moring.part.vo.in.RegisterPartRequestVo;
import com.dolijo.moring.part.vo.out.PartResponseVo;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springdoc.core.annotations.ParameterObject;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/parts")
@Tag(name = "부품", description = "부품 관련 API")
@Log4j2
public class PartController {
    private final PartService partService;

    @Operation(
            summary = "부품 등록",
            description = """
            부품 정보를 등록합니다.
            - 한글/영문 부품명, 교체주기, 유형 등 필수 입력
            - 권장 교체주기(km), 설명은 선택 입력
    """
    )
    @PostMapping("/")
    public BaseResponse<Long> registerPart(
            @RequestBody RegisterPartRequestVo requestVo
    ) {
        log.info("받은 VO: {}", requestVo);
        return BaseResponse.of(partService.registerPart(requestVo.toDto()));
    }


    @Operation(
            summary = "부품 전체 목록 조회",
            description = """  
                                차량 부품 전체 목록을 반환합니다.
                            """
    )
    @GetMapping("/")
    public BaseResponse<List<PartResponseVo>> getAllParts() {
        List<PartResponseDto> dtoList = partService.getAllParts();
        List<PartResponseVo> voList = dtoList.stream()
                .map(PartResponseVo::from)
                .collect(Collectors.toList());
        return BaseResponse.of(voList);
    }


    @Operation(
            summary = "회원의 등록 차량 부품 교환 이력 등록",
            description = """
                      특정 차량(VIN)에 대해 특정 부품(partId)을 교환한 이력을 기록합니다.
                      - 요청 성공 시, 교환 이력 ID 반환
    """
    )
    @PostMapping("/change-log")
    public BaseResponse<Long> registerPartChangeLog(
            @RequestBody RegisterPartChangeLogRequestVo requestVo
    ) {
        return BaseResponse.of(
                partService.registerPartChangeLog(requestVo.toDto())
        );
    }

    @Operation(
            summary = "차량의 부품 소모 상태 전체 조회",
            description = """
        회원의 차량(VIN)별 모든 부품의 최신 교체 이력/마감일/소모율을 반환합니다.
        dueDate가 null이면 등록한 교체 이력이 없는 부품입니다.
    """
    )
    @GetMapping("/status/{vin}")
    public BaseResponse<List<PartStatusListResponseDto>> getPartStatusList(
            @Parameter(example = "KNMK5C2HMLP000437", description = "차대번호")
            @PathVariable("vin") String vin)
    {
        return BaseResponse.of(partService.getPartStatusList(vin));
    }

}
