package com.dolijo.moring.notifycation.controller;

import com.dolijo.moring.common.base.BaseResponse;
import com.dolijo.moring.notifycation.dto.in.UnauthorizedUserRequestDto;
import com.dolijo.moring.notifycation.service.SseService;
import com.dolijo.moring.notifycation.service.NotificationService;
import com.dolijo.moring.notifycation.valueobject.NotificationDetailType;
import com.dolijo.moring.notifycation.vo.out.NotificationListResponseVo;
import com.dolijo.moring.notifycation.vo.out.SseConnectionStatusVo;
import com.dolijo.moring.security.dto.out.CustomMemberDetails;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/notifications")
@Tag(name = "알림", description = "알림 API")
@Log4j2
public class NotificationController {

    private final SseService sseService;
    private final NotificationService notificationService;

    /**
     * SSE
     */
    @Operation(summary = "차량 SSE 연결", description = """
            차량의 실시간 알림을 위한 SSE 연결을 생성합니다.
            한 회원이 여러 차량을 보유할 수 있으므로 차량 VIN으로만 연결을 관리합니다.
            """)
    @GetMapping(value = "/connect/{vin}", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter connectCar(
            @Parameter(description = "차량 VIN", required = true, example = "KNMK5C2HMLP000437")
            @PathVariable("vin") String vin
    ) {
        return sseService.createCarConnection(vin);
    }

    // 일반 알림 전송 API (운행 중 발생하는 알림)
    @Operation(summary = "일반 알림 전송", description = "차량 운행 중 발생하는 일반 알림을 전송합니다. (전방주시, 산소, 집중 알림 등)")
    @PostMapping("/send/general/{vin}")
    public BaseResponse<Void> sendGeneralNotification(
            @Parameter(description = "차량 VIN", required = true, example = "KNMK5C2HMLP000437")
            @PathVariable("vin") String vin,
            @Schema(description = """
                                    일반 알림 유형 : 
                                        FRONT_ALERT(전방주시 알림), OXYGEN_ALERT(산소 알림), 
                                        PART_ALERT(부품교환 알림), INSPECTION_ALERT(정기점검 알림), 
                                        SLEEP_ALERT(졸음 알림), UNAUTHORIZED_USER_ALERT(비인가 사용자 알림)
                                 """, required = true, example = "FRONT_ALERT")
            @RequestParam("notificationDetailType") NotificationDetailType notificationDetailType
    ) {
        sseService.sendGeneralNotification(vin, notificationDetailType);
        return BaseResponse.ok();
    }


    @Operation(summary = "차량 SSE 연결 해제", description = "차량의 SSE 연결을 해제합니다.")
    @DeleteMapping("/disconnect/{vin}")
    public BaseResponse<Void> disconnectCar(
            @Parameter(description = "차량 VIN", required = true, example = "KNMK5C2HMLP000437")
            @PathVariable("vin") String vin
    ) {
        sseService.disconnectCar(vin);
        return BaseResponse.ok();
    }

    @Operation(summary = "차량 연결 상태 확인", description = "특정 차량의 SSE 연결 상태를 확인합니다.")
    @GetMapping("/status/{vin}")
    public BaseResponse<Boolean> getCarConnectionStatus(
            @Parameter(description = "차량 VIN", required = true, example = "KNMK5C2HMLP000437")
            @PathVariable("vin") String vin
    ) {
        boolean isConnected = sseService.isCarConnected(vin);
        return BaseResponse.of(isConnected);
    }

    @Operation(summary = "SSE 전체 연결 상태 조회", description = "현재 SSE 연결 상태를 조회합니다.")
    @GetMapping("/status")
    public BaseResponse<SseConnectionStatusVo> getConnectionStatus() {
        SseConnectionStatusVo statusVo = SseConnectionStatusVo.builder()
                .carConnectionCount(sseService.getCarConnectionCount())
                .status("ACTIVE")
                .message("SSE 서비스가 정상적으로 동작 중입니다.")
                .build();

        return BaseResponse.of(statusVo);
    }

    @Operation(summary = "읽지 않은 알림 개수 조회", description = "차량(VIN)별 읽지 않은 알림 총 개수를 조회합니다.")
    @GetMapping("/{vin}/count")
    public BaseResponse<Long> getUnreadNotificationCountByVin(@PathVariable("vin") String vin) {
        return BaseResponse.of(notificationService.countUnreadNotificationsByCarVin(vin));
    }

    @Operation(summary = "읽지 않은 알림 리스트 조회", description = "차량(VIN)별 읽지 않은 알림 리스트(페이지네이션)를 조회합니다.")
    @GetMapping("/{vin}/unread")
    public BaseResponse<Slice<NotificationListResponseVo>> getUnreadNotificationListByVin(
            @PathVariable("vin") String vin,
            @Parameter(description = "페이지 번호", example = "0")
            @RequestParam(defaultValue = "0") int page,
            @Parameter(description = "페이지 크기", example = "20")
            @RequestParam(defaultValue = "20") int size
    ) {
        Pageable pageable = org.springframework.data.domain.PageRequest.of(page, size);
        var slice = notificationService.getUnreadNotificationListByCarVin(vin, pageable);
        return BaseResponse.of(
                                slice.map(
                                        dto -> NotificationListResponseVo.builder()
                                                .id(dto.getId())
                                                .notificationDetail(dto.getNotificationDetail())
                                                .createdAt(dto.getCreatedAt())
                                                .message(dto.getMessage())
                                                .build()
                                        )
                              );
    }

    @Operation(summary = "알림 단건 읽음 처리", description = "알림 ID 기준으로 읽음 처리합니다.")
    @PatchMapping("/read/{notificationId}")
    public BaseResponse<Void> readNotification(@PathVariable("notificationId") Long notificationId) {
        notificationService.readNotification(notificationId);
        return BaseResponse.ok();
    }

    @Operation(summary = "알림 전체 읽음 처리", description = "차량(VIN)별로 모든 알림을 읽음 처리하고, 처리된 개수를 반환합니다.")
    @PatchMapping("/{vin}/read-all")
    public BaseResponse<Long> readAllNotificationsByVin(@PathVariable("vin") String vin) {
        long updatedCount = notificationService.readAllNotificationsByVin(vin);
        return BaseResponse.of(updatedCount);
    }

    @Operation(summary = "비등록 운전자 인식 알림 전송", description = "비등록 운전자 인식 시 프론트에 모달 트리거 전송")
    @PostMapping("/send/unauthorized-user")
    public BaseResponse<Void> sendUnauthorizedUserDetected(@RequestBody UnauthorizedUserRequestDto request) {
        sseService.sendUnauthorizedUserDetected(request);
        return BaseResponse.ok();
    }



}
