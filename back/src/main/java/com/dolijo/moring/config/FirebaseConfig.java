package com.dolijo.moring.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;

import javax.annotation.PostConstruct;
import java.io.IOException;

/**
 * Firebase 초기화 설정 클래스
 * 서버 시작 시 Firebase Admin SDK를 자동으로 초기화합니다.
 */
@Slf4j
@Configuration
public class FirebaseConfig {

    /**
     * Firebase Admin SDK 초기화
     * 서비스 계정 키를 사용하여 Firebase 프로젝트에 연결
     */

    @Value("${firebase.config.path}")
    private String firebaseConfigPath;

    @Value("${firebase.config.projectId}")
    private String projectId;

    @PostConstruct
    public void initialize() {
        try {
            // Firebase가 이미 초기화되어 있는지 확인
            if (FirebaseApp.getApps().isEmpty()) {
                
                // resources 폴더에서 서비스 계정 키 파일 읽기
                ClassPathResource resource = new ClassPathResource(firebaseConfigPath);
                
                // Firebase 옵션 설정
                FirebaseOptions options = FirebaseOptions.builder()
                        .setCredentials(GoogleCredentials.fromStream(resource.getInputStream()))
                        .build();
                
                // Firebase 앱 초기화
                FirebaseApp.initializeApp(options);
                
                log.info("Firebase 초기화 완료!");
                
            } else {
                log.info("Firebase가 이미 초기화되어 있습니다.");
            }
            
        } catch (IOException e) {
            log.error("Firebase 초기화 실패: {}", e.getMessage(), e);
            throw new RuntimeException("Firebase 초기화에 실패했습니다.", e);
        }
    }
}