package com.dolijo.moring.notifycation.valueobject;

import lombok.Getter;


/** 알림 종류  */
@Getter
public enum NotificationType {
    PUSH("푸시"), GENERAL("일반");

    private final String description;
    NotificationType(String description) {
        this.description = description;
    }
}
