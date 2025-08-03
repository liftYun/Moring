package com.dolijo.moring.car.valueobject;

import lombok.Getter;

@Getter
public enum InspectionStatus {
    PENDING("점검 대기"),
    COMPLETED("점검 완료"),
    EXPIRED("점검 만료");

    private final String description;

    InspectionStatus(String description) {
        this.description = description;
    }
}