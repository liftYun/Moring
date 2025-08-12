package com.dolijo.moring.sms.service;

import com.dolijo.moring.sms.dto.SmsSendRequestDto;

public interface SmsService {
    void sendSms(SmsSendRequestDto dto);
}
