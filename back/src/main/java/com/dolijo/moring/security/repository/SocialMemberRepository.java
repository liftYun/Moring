package com.dolijo.moring.security.repository;

import com.dolijo.moring.member.entity.Member;
import com.dolijo.moring.member.entity.SocialMember;
import com.dolijo.moring.member.valueobject.SocialType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

@Repository
public interface SocialMemberRepository extends JpaRepository<SocialMember, Long> {

    // 이제 users.uuid 칼럼(memberUuid) 기준으로 조회
    Optional<SocialMember> findByMemberUuid(String memberUuid);
    Optional<SocialMember> findByMemberUuidAndType(String memberUuid, SocialType type);

    // 소셜 타입까지 같이 조회
//    Optional<SocialMember> findByMember_UuidAndType(String memberUuid, SocialType type);
//    @Query("SELECT sm FROM SocialMember sm WHERE sm.member.id = :id AND sm.type = :type")
//    Optional<SocialMember> findByMemberUuidAndType(
//            @Param("memberId") Long id,
//            @Param("type") SocialType type
//    );

    @Query("SELECT sm FROM SocialMember sm WHERE sm.member.id = :memberId AND sm.type = :type")
    Optional<SocialMember> findByMemberIdAndType(
            @Param("memberId") Long id,
            @Param("type") SocialType type
    );

    // users.uuid 기준 삭제
    @Modifying
//    @Query("delete from SocialMember r where r.member = :member")
    @Query("DELETE FROM SocialMember sm WHERE sm.member.uuid = :uuid")
    void deleteByMemberUuid(@Param("uuid") String uuid);

    // id 기준 삭제
    @Modifying
    @Transactional
//    @Query("DELETE FROM SocialMember sm WHERE sm.member.id = :memberId")
    @Query("UPDATE SocialMember sm " +
            "SET sm.tokenId = NULL, sm.fcmTokenId = NULL " +
//            "SET sm.tokenId = NULL " +
            "WHERE sm.member.id = :memberId")
    void deleteByMemberid(@Param("memberId") Long id);

    // users.uuid + 소셜타입 기준 삭제
    @Modifying
    @Query("delete from SocialMember r where r.member = :member and r.type = :type")
    void deleteByMemberUuidAndType(@Param("member") String memberUuid,
                                   @Param("type") SocialType type);

    void deleteByMember(Member member);

//    @Query("SELECT sm.tokenId FROM SocialMember sm WHERE sm.member.id = :memberId")
//    boolean isLoggedin(@Param("memberId") Long id);
    Boolean existsByMemberIdAndTokenIdIsNotNull(Long memberId);

    @Modifying
    @Query("UPDATE SocialMember sm SET sm.fcmTokenId = :fcmTokenId WHERE sm.member.id = :memberId AND sm.type = :socialType")
    int updateFcmTokenIdByMemberIdAndSocialType(@Param("memberId") Long memberId,
                                                @Param("socialType") SocialType socialType,
                                                @Param("fcmTokenId") String fcmTokenId);
}
