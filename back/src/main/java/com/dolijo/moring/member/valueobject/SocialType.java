package com.dolijo.moring.member.valueobject;

import lombok.Getter;

/** 소셜 종류  */
@Getter
public enum SocialType {
    LOCAL("로컬"), GOOGLE("구글"), KAKAO("카카오"), NAVER("네이버"), APPLE("애플");

    private final String description;
    SocialType(String description) {
        this.description = description;
    }
}