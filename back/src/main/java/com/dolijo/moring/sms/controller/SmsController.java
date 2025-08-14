package com.dolijo.moring.sms.controller;

import com.dolijo.moring.sms.dto.EmergencyRequestDto;
import com.dolijo.moring.sms.dto.UnauthorizedUserAlertLmsRequestDto;
import com.dolijo.moring.sms.service.SmsService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;



@RestController
@RequestMapping("/api/v1/sms")
@RequiredArgsConstructor
@Tag(name = "SMS", description = "SMS API")
public class SmsController {

    private final SmsService smsService;

    @PostMapping("/send/info")
    @Operation(summary = "SMS 정보 전송", description = "차량 모델명, 위치, 주소, 코드 정보를 포함한 SMS를 전송합니다.")
    public ResponseEntity<String> sendInfoSms(@RequestBody EmergencyRequestDto dto) {
        smsService.sendEmergencySms(dto);
        return ResponseEntity.ok("SMS 정보 전송 완료");
    }

    @PostMapping("/send/unauthorized-user")
    @Operation(summary = "비인가 사용자 알림 SMS 전송", description = "비인가 사용자 알림 SMS를 전송합니다.")
    public ResponseEntity<String> sendUnauthorizedUserAlertSms(@RequestBody UnauthorizedUserAlertLmsRequestDto dto) {
        smsService.sendUnauthorizedUserAlertSms(dto);
        return ResponseEntity.ok("비인가 사용자 알림 SMS 전송 완료");
    }
}
