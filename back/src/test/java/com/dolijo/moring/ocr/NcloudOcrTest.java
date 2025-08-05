package com.dolijo.moring.ocr;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.http.*;
import org.springframework.web.client.RestTemplate;

import java.util.*;

public class NcloudOcrTest {

    @Test
    public void callNcloudOcrApi() throws Exception {
        String apiUrl = "https://oqtnvjdj34.apigw.ntruss.com/custom/v1/44865/93935de02c44ae657c0d9d7d60e5e9b3fc08985403bf479497a0935aeff4c0c7/general";        // 예: https://api.ocr.ncloud.com/v1/...
        String secretKey = "bmJzakt6eExRdWRNUVNqVkdUbm1sdXJacXVmVHFkZ2o=";
        String imageUrl = "https://freedoc.co.kr/wp-content/uploads/2023/07/word_09_01.jpg";    // 외부 이미지 URL 또는 S3 등

        // 1. 요청 Body 생성
        Map<String, Object> imageMap = new HashMap<>();
        imageMap.put("format", "jpg");
        imageMap.put("name", "demo");
        imageMap.put("url", imageUrl);

        Map<String, Object> requestJson = new HashMap<>();
        requestJson.put("images", List.of(imageMap));
        requestJson.put("requestId", UUID.randomUUID().toString());
        requestJson.put("version", "V2");
        requestJson.put("timestamp", System.currentTimeMillis());

        ObjectMapper objectMapper = new ObjectMapper();
        String payload = objectMapper.writeValueAsString(requestJson);

        // 2. 헤더 세팅
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.set("X-OCR-SECRET", secretKey);

        HttpEntity<String> entity = new HttpEntity<>(payload, headers);

        // 3. POST 호출
        RestTemplate restTemplate = new RestTemplate();
        ResponseEntity<String> response = restTemplate.exchange(
                apiUrl,
                HttpMethod.POST,
                entity,
                String.class
        );

        // 4. 결과 출력
        System.out.println("Status: " + response.getStatusCode());
        System.out.println("Body: " + response.getBody());
    }
}
