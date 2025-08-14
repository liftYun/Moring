package com.dolijo.moring.sms.service;

import com.dolijo.moring.sms.dto.EmergencyRequestDto;
import com.dolijo.moring.sms.dto.UnauthorizedUserAlertLmsRequestDto;

public interface SmsService {
    void sendEmergencySms(EmergencyRequestDto dto);
    void sendUnauthorizedUserAlertSms(UnauthorizedUserAlertLmsRequestDto dto);
}
