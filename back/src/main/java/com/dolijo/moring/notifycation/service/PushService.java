package com.dolijo.moring.notifycation.service;

import com.dolijo.moring.batch.dto.FCMNotificationRequestDto;
import com.dolijo.moring.common.base.BaseResponseStatus;
import com.dolijo.moring.common.exception.BaseException;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import lombok.extern.log4j.Log4j2;
import org.springframework.stereotype.Service;

@Service
@Log4j2
public class PushService {
    public void sendPushNotification(FCMNotificationRequestDto requestDto) {
        String fcmToken = requestDto.getFcmToken();
        if (fcmToken == null || fcmToken.trim().isEmpty()) {
            log.info("FCM 토큰이 없으므로 푸시 알림을 전송하지 않습니다. 요청: {}", requestDto);
            return;
        }
        try {
            Message.Builder messageBuilder = Message.builder()
                    .setToken(fcmToken)
                    .setNotification(Notification.builder()
                            .setTitle(requestDto.getTitle())
                            .setBody(requestDto.getBody())
                            .build());

            if (requestDto.getData() != null && !requestDto.getData().isEmpty()) {
                messageBuilder.putAllData(requestDto.getData());
            }

            String result = FirebaseMessaging.getInstance().send(messageBuilder.build());
            log.info("개별 사용자 알림 전송 성공: {}", result);
        } catch (Exception e) {
            log.error("개별 사용자 알림 전송 실패: {}", e.getMessage(), e);
            throw new BaseException(BaseResponseStatus.PUSH_SEND_FAIL);
        } finally {
            log.info("개별 사용자 알림 전송 시작 - 요청: {}", requestDto);
        }
    }
}
