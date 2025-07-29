package com.dolijo.moring.security.service;

import com.dolijo.moring.member.entity.Member;
import com.dolijo.moring.member.repository.MemberRepository;
import com.dolijo.moring.security.dto.in.RegistRequestDto;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

/**
 * 회원 가입 및 소셜 로그인 사용자 등록 서비스 (JPA 기반)
 */
@Service
@Transactional
public class JoinService {

    private final MemberRepository memberRepository;

    public JoinService(MemberRepository memberRepository) {
        this.memberRepository = memberRepository;
    }

    /**
     * 일반 회원 가입 처리
     * @param dto 가입 요청 데이터
     */
    public void joinProcess(RegistRequestDto dto) {
        String email = dto.getEmail();
        // 이메일 중복 체크
        if (memberRepository.existsByEmail(email)) {
            // 이미 존재 시 간단 리턴 (필요 시 예외 처리)
            return;
        }
        // 신규 회원 엔티티 생성
        Member member = Member.builder()
                .uuid(UUID.randomUUID().toString())
                .email(dto.getEmail())
                .nickName(dto.getNickName())
                .build();
        memberRepository.save(member);
    }

    /**
     * 소셜 로그인(카카오) 사용자 최초 등록 또는 조회
     * @param email 카카오 계정 이메일
     * @param nickname 카카오 프로필 닉네임
     * @return 등록된 또는 기존 UserEntity
     */
    public Member registerKakaoUserIfNotExist(String email, String nickname) {
        return memberRepository.findByEmail(email)
                .orElseGet(() -> {
                    Member member = Member.builder()
                            .uuid(UUID.randomUUID().toString())
                            .email(email)
                            .nickName(nickname)
                            .build();
                    return memberRepository.save(member);
                });
    }

    public Member registerSocialUserIfNotExist(String email, String nickname) {
        return memberRepository.findByEmail(email)
                .orElseGet(() -> {
                    Member member = Member.builder()
                            .uuid(UUID.randomUUID().toString())
                            .email(email)
                            .nickName(nickname)
                            .build();
                    return memberRepository.save(member);
                });
    }
}
