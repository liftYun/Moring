package com.dolijo.moring.batch.dto;

import lombok.*;

import java.util.Map;

@Getter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@ToString
public class FCMNotificationRequestDto {
    private String fcmToken;
    private String title;
    private String body;
    private String image;
    private String type;
    private Map<String, String> data;


}
