package com.dolijo.moring;


import com.dolijo.moring.common.base.BaseResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.Parameters;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/health")
public class TestController {

    @Operation(summary = "헬스 체크", description = "서버 상태 확인용 API (200 OK)")
    @Parameters({
            @Parameter(name = "name", description = "사용자 이름", required = true),
            @Parameter(name = "value", description = "전달할 값", required = true)
    })
    @GetMapping
    public BaseResponse<Void> healthCheck() {
        return BaseResponse.ok();
    }
}
