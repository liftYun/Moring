package com.dolijo.moring.security.repository;

import com.dolijo.moring.member.entity.Member;
import com.dolijo.moring.member.entity.SocialMember;
import com.dolijo.moring.member.valueobject.SocialType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface SocialMemberRepository extends JpaRepository<SocialMember, Long> {

    // 이제 users.uuid 칼럼(memberUuid) 기준으로 조회
    Optional<SocialMember> findByMemberUuid(String memberUuid);

    // 소셜 타입까지 같이 조회
    Optional<SocialMember> findByMemberUuidAndType(String memberUuid, SocialType type);

    // users.uuid 기준 삭제
    @Modifying
    @Query("delete from SocialMember r where r.member = :member")
    void deleteByMemberUuid(@Param("member") String memberUuid);

    // users.uuid + 소셜타입 기준 삭제
    @Modifying
    @Query("delete from SocialMember r where r.member = :member and r.type = :type")
    void deleteByMemberUuidAndType(@Param("member") String memberUuid,
                                   @Param("type") SocialType type);

    void deleteByMember(Member member);
}
