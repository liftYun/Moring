//package org.example.oauthtest.security.service;
//
//import org.example.oauthtest.security.entity.RefreshTokenEntity;
//import org.example.oauthtest.security.entity.SocialType;
//import org.example.oauthtest.security.jwt.JWTUtil;
//import org.example.oauthtest.security.repository.RefreshTokenRepository;
//import org.springframework.stereotype.Service;
//import org.springframework.transaction.annotation.Transactional;
//
//import java.util.Date;
//
///**
// * 리프레시 토큰 검증 및 저장/삭제 서비스 (JPA 기반)
// */
//@Service
//@Transactional
//public class RefreshTokenService {
//
//    private final RefreshTokenRepository refreshTokenRepository;
//    private final JWTUtil jwtUtil;
//
//    public RefreshTokenService(RefreshTokenRepository refreshTokenRepository, JWTUtil jwtUtil) {
//        this.refreshTokenRepository = refreshTokenRepository;
//        this.jwtUtil = jwtUtil;
//    }
//
//    public boolean isValid(String uuid, String refreshToken, SocialType type) {
//        // 1) 서명·만료 검증
//        try {
//            jwtUtil.parseClaims(refreshToken);
//        } catch (Exception e) {
//            return false;
//        }
//        // 2) DB 조회
//        return refreshTokenRepository
//                .findByMemberUuidAndType(uuid, type)
//                .filter(ent ->
//                        ent.getToken().equals(refreshToken)
//                                && ent.getExpiresAt().after(new Date()))
//                .isPresent();
//    }
//
//    public void deleteToken(String uuid) {
//        // 타입별로 지우기
//        refreshTokenRepository.deleteByMemberUuid(uuid);
//    }
//
//    public void saveToken(String uuid, SocialType type, String refreshToken) {
//        // 1) 기존 토큰 삭제
//        refreshTokenRepository.deleteByMemberUuid(uuid);
//        // 2) 새 토큰 저장
//        RefreshTokenEntity entity = RefreshTokenEntity.builder()
//                .memberUuid(uuid)
//                .type(type)
//                .token(refreshToken)
//                .expiresAt(new Date(System.currentTimeMillis() + jwtUtil.getRefreshExpiredMs()))
//                .build();
//        refreshTokenRepository.save(entity);
//    }
//
//    // OAuth2 핸들러에서 alias로 사용할 때도 type 전달
//    public void createOrReplace(String uuid, SocialType type, String refreshToken) {
//        saveToken(uuid, type, refreshToken);
//    }
//}

package com.dolijo.moring.security.service;

import com.dolijo.moring.member.entity.Member;
import com.dolijo.moring.member.entity.SocialMember;
import com.dolijo.moring.member.valueobject.SocialType;
import com.dolijo.moring.security.jwt.JWTUtil;
import com.dolijo.moring.security.repository.SocialMemberRepository;
import com.dolijo.moring.security.repository.MemberRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Date;

/**
 * 리프레시 토큰 검증 및 저장/삭제 서비스 (JPA 기반)
 */
@Service
@Transactional
public class SocialMemberService {

    private final SocialMemberRepository socialMemberRepository;
    private final MemberRepository memberRepository;
    private final JWTUtil jwtUtil;

    public SocialMemberService(SocialMemberRepository socialMemberRepository,
                               MemberRepository memberRepository,
                               JWTUtil jwtUtil) {
        this.socialMemberRepository = socialMemberRepository;
        this.memberRepository = memberRepository;
        this.jwtUtil = jwtUtil;
    }

    /**
     * 전달받은 리프레시 토큰이 유효한지 검사합니다.
     */
    public boolean isValid(String uuid, String refreshToken, SocialType type) {
        // 1) 토큰 서명 및 만료 검증
        try {
            jwtUtil.parseClaims(refreshToken);
        } catch (Exception e) {
            return false;
        }
        // 2) DB에 저장된 토큰과 일치하고, 아직 만료되지 않았는지 확인
        return socialMemberRepository
                .findByMemberUuidAndType(uuid, type)
                .filter(ent ->
                        ent.getTokenId().equals(refreshToken) &&
                                ent.getExpiresAt().after(new Date()))
                .isPresent();
    }

    /**
     * 지정된 사용자(UUID)의 모든 리프레시 토큰을 삭제합니다.
     */
    public void deleteToken(String uuid) {
        socialMemberRepository.deleteByMemberUuid(uuid);
    }

    /**
     * 지정된 사용자(UUID)에 대해 새로운 리프레시 토큰을 저장합니다.
     * 기존 토큰은 먼저 삭제됩니다.
     */
    public void saveToken(String uuid, SocialType type, String refreshToken) {
        // 1) 기존 토큰 삭제
        socialMemberRepository.deleteByMemberUuid(uuid);

        // 2) UserEntity 조회 (member 필수)
        Member member = memberRepository.findByUuid(uuid)
                .orElseThrow(() ->
                        new IllegalArgumentException("Invalid user UUID: " + uuid));

        // 3) 새로운 RefreshTokenEntity 생성 및 저장
        SocialMember entity = SocialMember.builder()
                .member(member)  // ← UserEntity를 반드시 설정해야 null 에러 방지
                .type(type)
                .tokenId(refreshToken)
                .expiresAt(new Date(System.currentTimeMillis()
                        + jwtUtil.getRefreshExpiredMs()))
                .build();
        socialMemberRepository.save(entity);
    }

    /**
     * OAuth2 핸들러 등에서 alias로 호출할 수 있도록 createOrReplace 제공
     */
    public void createOrReplace(String uuid, SocialType type, String refreshToken) {
        saveToken(uuid, type, refreshToken);
    }

}
