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



}