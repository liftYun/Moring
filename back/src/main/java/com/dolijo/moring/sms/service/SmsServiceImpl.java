package com.dolijo.moring.sms.service;

import com.dolijo.moring.sms.dto.SmsSendRequestDto;
import lombok.extern.log4j.Log4j2;
import net.nurigo.sdk.NurigoApp;
import net.nurigo.sdk.message.model.Message;
import net.nurigo.sdk.message.request.SingleMessageSendingRequest;
import net.nurigo.sdk.message.response.SingleMessageSentResponse;
import net.nurigo.sdk.message.service.DefaultMessageService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
@Log4j2
public class SmsServiceImpl implements SmsService {
    private final DefaultMessageService messageService;
    private final String systemPhoneNumber;
    private final String toPhoneNumber;

    public SmsServiceImpl(
            @Value("${coolsms.api-key}") String apiKey,
            @Value("${coolsms.api-secret}") String apiSecret,
            @Value("${coolsms.system-phone-number}") String systemPhoneNumber,
            @Value("${coolsms.to}") String toPhoneNumber
    ) {
        this.messageService = NurigoApp.INSTANCE.initialize(apiKey, apiSecret, "https://api.coolsms.co.kr");
        this.systemPhoneNumber = systemPhoneNumber;
        this.toPhoneNumber = toPhoneNumber;
    }

    @Override
    public void sendSms(SmsSendRequestDto dto) {
        StringBuilder sb = new StringBuilder();
        sb.append("[Moring 신고 시스템]\n");
        sb.append("차량정보: ").append(dto.getModelName()).append("\n");
        //  sb.append("위치: ").append(dto.getLatitude()).append(", ").append(dto.getLongitude()).append("\n");
        if (dto.getAddress() != null) {
            sb.append("주소: ").append(dto.getAddress()).append("\n");
        }
        sb.append("\n응급상황이 감지되었습니다. 신속한 구조를 부탁드립니다.\n");
        // 카카오맵 링크 추가
        sb.append("지도 확인: https://map.kakao.com/link/map/차량위치,")
          .append(dto.getLatitude()).append(",").append(dto.getLongitude());
        Message message = new Message();
        message.setFrom(systemPhoneNumber);
        message.setTo(toPhoneNumber); // 수신자 전화번호
        message.setText(sb.toString());
        log.info("전송 메시지: {}", message.getText());
        SingleMessageSentResponse response = messageService.sendOne(new SingleMessageSendingRequest(message));
        log.info("SMS 전송 결과: {}", response);
    }
}
