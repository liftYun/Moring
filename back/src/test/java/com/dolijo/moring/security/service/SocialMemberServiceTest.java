package com.dolijo.moring.security.service;

import com.dolijo.moring.member.repository.MemberRepository;
import com.dolijo.moring.security.repository.SocialMemberRepository;
import lombok.extern.log4j.Log4j2;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@Log4j2
class SocialMemberServiceTest {

    @Autowired
    SocialMemberRepository socialMemberRepository;

    @Test
     void test0() {
        Long id = 2L;
        log.info(socialMemberRepository.existsByMemberIdAndTokenIdIsNotNull(id));
    }

    @Test
    void test1() {
        Long id = 2L;
        socialMemberRepository.deleteByMemberid(id);
    }


}