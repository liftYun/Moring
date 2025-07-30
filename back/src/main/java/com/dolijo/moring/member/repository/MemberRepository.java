package com.dolijo.moring.member.repository;

import com.dolijo.moring.member.entity.Member;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
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
     * 회원 uuid로 회원 id 조회
     */
    @Query("select m.id from Member m where m.uuid = :memberUuid")
    Optional<Long> findIdByMemberUuid(@Param("memberUuid") String memberUuid);


    /**
     * UUID로 사용자 조회
     */
//    Optional<Member> findByUuid(String uuid);

    /**
     * 이메일로 사용자 조회
     */
    Optional<Member> findByEmail(String email);
}
