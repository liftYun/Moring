package com.dolijo.moring.part.entity.valueobject;

import lombok.Getter;

/** 부품 종류  */
@Getter
public enum PartType {
    CONSUMABLE("소모품"), EQUIPMENT("장비"), OTHER("기타");

    private final String description;
    PartType(String description) {
        this.description = description;
    }
}