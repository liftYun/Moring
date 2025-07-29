package com.dolijo.moring.member.repository;

import com.dolijo.moring.member.entity.Member;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface MemberRepository extends JpaRepository<Member,Long> {

    Optional<Member> findByMemberUuid(String memberUuid);
}
