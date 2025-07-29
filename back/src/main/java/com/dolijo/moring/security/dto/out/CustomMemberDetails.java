package com.dolijo.moring.security.dto.out;

import com.dolijo.moring.member.entity.Member;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.ArrayList;
import java.util.Collection;

public class CustomMemberDetails implements UserDetails {

    private final Member member;

    public CustomMemberDetails(Member member) {

        this.member = member;
    }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {

        Collection<GrantedAuthority> collection = new ArrayList<>();

        collection.add(new GrantedAuthority() {
            @Override
            public String getAuthority() {

                return "ROLE_USER";
            }
        });

        return collection;
    }
    public Member getMemberEntity() {
        return this.member;
    }

    public Long getMemberId() { return member.getId(); }

    public String getUserUuid() { return member.getUuid(); }

    public String getUserEmail() { return  member.getEmail(); }

    public String getUserNickname() { return member.getNickName(); }

    @Override
    public String getPassword() {
        return null;
    }

    @Override
    public String getUsername() {
        return null;
    }

    @Override
    public boolean isAccountNonExpired() {
        return UserDetails.super.isAccountNonExpired();
    }

    @Override
    public boolean isAccountNonLocked() {
        return true;
    }

    @Override
    public boolean isCredentialsNonExpired() {
        return true;
    }


    @Override
    public boolean isEnabled() {
        return true;
    }
}
