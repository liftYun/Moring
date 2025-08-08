package com.dolijo.moring.notifycation.valueobject;

import lombok.Getter;

/**  알림 종류  */
@Getter
public enum NotificationDetailType {
    FRONT_ALERT("전방주시 알림"),
    OXYGEN_ALERT("산소 알림"),
    DISTRACTION_ALERT("집중 알림"),
    PART_ALERT("부품교환 알림"),
    INSPECTION_ALERT("정기점검 알림");

    private final String description;
    NotificationDetailType(String description) {
        this.description = description;
    }
}