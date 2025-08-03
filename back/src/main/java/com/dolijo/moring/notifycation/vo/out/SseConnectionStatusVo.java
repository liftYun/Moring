package com.dolijo.moring.notifycation.vo.out;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
@Schema(description = "SSE 연결 상태 정보")
public final class SseConnectionStatusVo {

    @Schema(description = "연결된 차량 수")
    private final int carConnectionCount;

    @Schema(description = "서비스 상태")
    private final String status;

    @Schema(description = "상태 메시지")
    private final String message;
}
