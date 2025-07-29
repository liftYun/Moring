package com.dolijo.moring.member.repository;

import com.dolijo.moring.member.entity.Member;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface MemberRepository extends JpaRepository<Member,Long> {

    Optional<Member> findByUuid(String memberUuid);
    /**
     * 이메일(로그인 ID) 존재 여부 확인
     */
    boolean existsByEmail(String email);

    /**
     * UUID로 사용자 조회
     */
//    Optional<Member> findByUuid(String uuid);

    /**
     * 이메일로 사용자 조회
     */
    Optional<Member> findByEmail(String email);
}
