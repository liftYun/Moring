package com.dolijo.moring.sms.service;

import com.dolijo.moring.car.entity.Car;
import com.dolijo.moring.car.entity.UnauthorizedUserLog;
import com.dolijo.moring.car.repository.CarRepository;
import com.dolijo.moring.car.repository.UnauthorizedUserLogRepository;
import com.dolijo.moring.common.base.BaseResponseStatus;
import com.dolijo.moring.common.exception.BaseException;
import com.dolijo.moring.sms.dto.EmergencyRequestDto;
import com.dolijo.moring.sms.dto.UnauthorizedUserAlertLmsRequestDto;
import java.time.LocalDate;
import java.time.LocalDateTime;

import lombok.extern.log4j.Log4j2;
import net.nurigo.sdk.NurigoApp;
import net.nurigo.sdk.message.model.Message;
import net.nurigo.sdk.message.request.SingleMessageSendingRequest;
import net.nurigo.sdk.message.response.SingleMessageSentResponse;
import net.nurigo.sdk.message.service.DefaultMessageService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Log4j2
@Transactional
public class SmsServiceImpl implements SmsService {
    private final DefaultMessageService messageService;
    private final String systemPhoneNumber;
    private final String toPhoneNumber;
    private final CarRepository carRepository;
    private final UnauthorizedUserLogRepository unauthorizedUserLogRepository;

    public SmsServiceImpl(
            @Value("${coolsms.api-key}") String apiKey,
            @Value("${coolsms.api-secret}") String apiSecret,
            @Value("${coolsms.system-phone-number}") String systemPhoneNumber,
            @Value("${coolsms.to}") String toPhoneNumber,
            CarRepository carRepository,
            UnauthorizedUserLogRepository unauthorizedUserLogRepository
    ) {
        this.messageService = NurigoApp.INSTANCE.initialize(apiKey, apiSecret, "https://api.coolsms.co.kr");
        this.systemPhoneNumber = systemPhoneNumber;
        this.toPhoneNumber = toPhoneNumber;
        this.carRepository = carRepository;
        this.unauthorizedUserLogRepository = unauthorizedUserLogRepository;
    }

    @Override
    public void sendEmergencySms(EmergencyRequestDto dto) {
        Car findCar = carRepository.findByVin(dto.getVin())
                .orElseThrow(() -> new BaseException(BaseResponseStatus.NO_EXIST_CAR));
        StringBuilder sb = new StringBuilder();
        sb.append("[Moring 신고 시스템]\n");
        sb.append("차량정보: ").append(findCar.getModelName()).append("\n");
        //  sb.append("위치: ").append(dto.getLatitude()).append(", ").append(dto.getLongitude()).append("\n");
        if (dto.getAddress() != null) {
            sb.append("주소: ").append(dto.getAddress()).append("\n");
        }
        sb.append("\n응급상황이 감지되었습니다. 신속한 구조를 부탁드립니다.\n");
        // 카카오맵 링크 추가
        sb.append("위치 확인: https://map.kakao.com/link/map/차량위치,")
          .append(dto.getLatitude()).append(",").append(dto.getLongitude());
        Message message = new Message();
        message.setFrom(systemPhoneNumber);
        message.setTo(toPhoneNumber); // 수신자 전화번호
        message.setText(sb.toString());
        log.info("전송 메시지: {}", message.getText());
        SingleMessageSentResponse response = messageService.sendOne(new SingleMessageSendingRequest(message));
        log.info("SMS 전송 결과: {}", response);
    }

    @Override
    public void sendUnauthorizedUserAlertSms(UnauthorizedUserAlertLmsRequestDto dto) {
        Car findCar = carRepository.findByVin(dto.getVin())
                .orElseThrow(() -> new BaseException(BaseResponseStatus.NO_EXIST_CAR));
        // 템플릿 작성
        StringBuilder sb = new StringBuilder();
        sb.append("[Moring 비인가 운전자 탑승 알림]\n");
        sb.append("차량명: ").append(findCar.getNickname()).append("\n");
        sb.append("위치 확인: https://map.kakao.com/link/map/차량위치,")
                .append(dto.getLatitude()).append(",").append(dto.getLongitude()).append("\n");
        sb.append("탑승 일시: ").append(LocalDate.now()).append("\n");
        sb.append("이미지: ").append(dto.getImageUrl());
        Message message = new Message();
        message.setFrom(systemPhoneNumber);
        message.setTo(toPhoneNumber);
        message.setText(sb.toString());
        // sms 전송 및 로그 테이블 저장
        log.info("전송 메시지: {}", message.getText());
        SingleMessageSentResponse response = messageService.sendOne(new SingleMessageSendingRequest(message));
        log.info("SMS 전송 결과: {}", response);
        unauthorizedUserLogRepository.save(
                UnauthorizedUserLog.builder()
                        .car(findCar)
                        .unauthorizedUserImgUrl(dto.getImageUrl())
                        .createdAt(LocalDateTime.now())
                        .build()
        );

    }


}
