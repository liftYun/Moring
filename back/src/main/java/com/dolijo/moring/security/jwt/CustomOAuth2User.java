package com.dolijo.moring.security.jwt;

import com.dolijo.moring.member.entity.Member;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.core.user.DefaultOAuth2User;

import java.util.Collection;
import java.util.Collections;
import java.util.Map;

/**
 * OAuth2User와 UserEntity를 연결하는 커스텀 OAuth2User 구현체
 */
public class CustomOAuth2User extends DefaultOAuth2User {

    private final Member member;

    /**
     * @param member       DB에 저장된 사용자 엔티티
     * @param attributes OAuth2 프로바이더(카카오)로부터 받은 사용자 정보 맵
     */
    public CustomOAuth2User(Member member, Map<String, Object> attributes) {
        // DefaultOAuth2User 생성: 권한, 속성, 사용자 식별자 키
        super(getAuthorities(member), attributes, "id");
        this.member = member;
    }

    /**
     * UserEntity 기반 권한 목록 생성
     */
    private static Collection<? extends GrantedAuthority> getAuthorities(Member member) {
        // user.getRole()이 "ROLE_USER" 또는 "ROLE_ADMIN" 형식으로 저장되어 있다고 가정
        String role = "ROLE_USER";
        return Collections.singletonList(new SimpleGrantedAuthority(role));
    }

    /**
     * UserEntity 반환
     */
    public Member getMember() {
        return member;
    }

    /**
     * 사용자 식별자(username)로 사용할 name 속성 반환
     */
    @Override
    public String getName() {
        // 기본 키로 사용할 속성. 카카오 프로필 JSON에서 "id" 필드를 사용하거나,
        // DB 사용자 UUID를 사용하려면 user.getId() 반환으로 변경
        Object oauthId = getAttributes().get("id");
        return oauthId != null ? oauthId.toString() : member.getUuid();
    }
}
