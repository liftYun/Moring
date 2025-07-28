package com.dolijo.moring.member.valueobject;

import lombok.Getter;

/** 일반 알림 종류  */
@Getter
public enum GeneralNotificationType {
    FRONT_ALERT("전방주시 알림"), OXYGEN_ALERT("산소 알림"), DISTRACTION_ALERT("집중 알림");

    private final String description;
    GeneralNotificationType(String description) {
        this.description = description;
    }
}