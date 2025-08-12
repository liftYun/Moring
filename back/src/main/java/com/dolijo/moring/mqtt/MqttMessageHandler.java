package com.dolijo.moring.mqtt;

import com.dolijo.moring.notifycation.service.PushService;
import com.dolijo.moring.batch.dto.FCMNotificationRequestDto;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.integration.annotation.ServiceActivator;
import org.springframework.messaging.Message;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
@RequiredArgsConstructor
@Slf4j
public class MqttMessageHandler {
    
    private final PushService pushService;
    private final ObjectMapper objectMapper;
    
    @ServiceActivator(inputChannel = "mqttInputChannel")
    public void handleMessage(Message<?> message) {
        try {
            String payload = new String((byte[]) message.getPayload());
            log.info("Received MQTT message: {}", payload);
            
            Map<String, Object> alertData = objectMapper.readValue(payload, Map.class);
            String alertType = (String) alertData.get("type");
            String vinNumber = (String) alertData.get("vin_number");
            String timestamp = (String) alertData.get("timestamp");
            
            log.info("Alert received - Type: {}, VIN: {}, Time: {}", alertType, vinNumber, timestamp);
            
            // FCM 푸시 알림 전송
            sendFcmNotification(vinNumber, alertType, alertData);
            
        } catch (Exception e) {
            log.error("Error processing MQTT message", e);
        }
    }
    
    private void sendFcmNotification(String vinNumber, String alertType, Map<String, Object> alertData) {
        try {
            String title = getAlertTitle(alertType);
            String body = getAlertBody(alertType, alertData);
            
            // TODO: VIN 번호로 FCM 토큰 조회 (현재는 임시로 빈 문자열)
            String fcmToken = ""; 
            
            if (fcmToken != null && !fcmToken.isEmpty()) {
                FCMNotificationRequestDto requestDto = FCMNotificationRequestDto.builder()
                    .fcmToken(fcmToken)
                    .title(title)
                    .body(body)
                    .data(Map.of(
                        "alertType", alertType,
                        "vinNumber", vinNumber,
                        "timestamp", (String) alertData.get("timestamp")
                    ))
                    .build();
                
                pushService.sendPushNotification(requestDto);
                log.info("FCM notification sent for VIN: {}, alert: {}", vinNumber, alertType);
            } else {
                log.warn("FCM token not found for VIN: {}", vinNumber);
            }
        } catch (Exception e) {
            log.error("Error sending FCM notification", e);
        }
    }
    
    private String getAlertTitle(String alertType) {
        return switch (alertType) {
            case "FRONT_ALERT" -> "🚨 전방주시 알림";
            case "OXYGEN_ALERT" -> "⚠️ 산소 알림";
            case "DISTRACTION_ALERT" -> "⚠️ 집중 알림";
            case "PART_ALERT" -> "⚠️ 부품 알림";
            case "INSPECTION_ALERT" -> "⚠️ 점검 알림";
            default -> "운전 알림";
        };
    }
    
    private String getAlertBody(String alertType, Map<String, Object> alertData) {
        return switch (alertType) {
            case "FRONT_ALERT" -> "전방을 주시하세요. 안전 운전에 집중하세요.";
            case "OXYGEN_ALERT" -> "산소 수치에 주의가 필요합니다. 환기를 확인하세요.";
            case "DISTRACTION_ALERT" -> "집중력이 떨어졌습니다. 안전한 곳에 정차하세요.";
            case "PART_ALERT" -> "차량 부품에 문제가 감지되었습니다. 점검이 필요합니다.";
            case "INSPECTION_ALERT" -> "차량 점검이 필요합니다. 정비소를 방문하세요.";
            default -> "운전 중 주의가 필요합니다.";
        };
    }
}
