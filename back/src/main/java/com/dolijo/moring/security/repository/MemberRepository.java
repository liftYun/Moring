package com.dolijo.moring.security.repository;

import com.dolijo.moring.member.entity.Member;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

/**
 * JPA를 이용한 User 엔티티 CRUD 및 사용자 조회용 리포지토리
 */
@Repository
public interface MemberRepository extends JpaRepository<Member, Long> {

    /**
     * 이메일(로그인 ID) 존재 여부 확인
     */
    boolean existsByEmail(String email);

    /**
     * UUID로 사용자 조회
     */
    Optional<Member> findByUuid(String uuid);

    /**
     * 이메일로 사용자 조회
     */
    Optional<Member> findByEmail(String email);
}
