package com.dolijo.moring.security.service;

import com.dolijo.moring.common.base.BaseResponseStatus;
import com.dolijo.moring.common.exception.BaseException;
import com.dolijo.moring.member.entity.Member;
import com.dolijo.moring.member.repository.MemberRepository;
import com.dolijo.moring.security.dto.out.CustomMemberDetails;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 사용자 정보(UserDetails)를 조회하는 서비스 (JPA 기반)
 * - username/password 로그인 및 리프레시 토큰 갱신 시 사용
 */
@Service
@Transactional(readOnly = true)
public class CustomUserDetailsService implements UserDetailsService {

    private final MemberRepository memberRepository;

    public CustomUserDetailsService(MemberRepository memberRepository) {
        this.memberRepository = memberRepository;
    }

    /**
     * 이메일로 UserEntity 조회 후 CustomUserDetails 반환
     * @param email 로그인 폼에서 입력받은 사용자 이메일
     * @return CustomUserDetails
     * @throws UsernameNotFoundException 사용자 미존재 시 예외 발생
     */
//    @Override
//    public UserDetails loadUserByUsername(String userEmail) throws UsernameNotFoundException {
//        UserEntity user = userRepository.findByUserEmail(userEmail)
//                .orElseThrow(() -> new UsernameNotFoundException(
//                        "User not found with email: " + userEmail));
//        return new CustomUserDetails(user);
//    }
    @Override
    public UserDetails loadUserByUsername(String email) throws UsernameNotFoundException {
        Member member = memberRepository.findByEmail(email)
                .orElseThrow(() -> new UsernameNotFoundException(
                        "User not found with email: " + email));
        return new CustomMemberDetails(member);
    }

    /**
     * UUID로 UserEntity 조회 후 CustomUserDetails 반환
     * @param memberUuid 리프레시 토큰 검증 후 추출된 사용자 UUID
     * @return CustomUserDetails
     * @throws UsernameNotFoundException 사용자 미존재 시 예외 발생
     */
    public CustomMemberDetails loadMemberUuid(String memberUuid) throws UsernameNotFoundException {
        Member member = memberRepository.findByUuid(memberUuid)
                .orElseThrow(() -> new UsernameNotFoundException(
                        "User not found with ID: " + memberUuid));
        return new CustomMemberDetails(member);
    }

    @Transactional(readOnly = false)
    public int updateNickName(String uuid, String nickName) throws UsernameNotFoundException {
        Member member = memberRepository.findByUuid(uuid)
                .orElseThrow(() -> new BaseException(BaseResponseStatus.NO_EXIST_MEMBER ));

        return memberRepository.updateNickNameById(member.getUuid(), nickName);
    }
}
