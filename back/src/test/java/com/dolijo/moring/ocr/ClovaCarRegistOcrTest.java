package com.dolijo.moring.ocr;

import com.dolijo.moring.ai.vo.out.CarRegistrationOcrResponseVo;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.log4j.Log4j2;
import org.junit.jupiter.api.Test;
import org.springframework.http.*;
import org.springframework.web.client.RestTemplate;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.*;



@Log4j2
public class ClovaCarRegistOcrTest {
    private final String SECRET = "bmJzakt6eExRdWRNUVNqVkdUbm1sdXJacXVmVHFkZ2o=";
    private final String apiUrl = "https://oqtnvjdj34.apigw.ntruss.com/custom/v1/44865/93935de02c44ae657c0d9d7d60e5e9b3fc08985403bf479497a0935aeff4c0c7/general";        // 예: https://api.ocr.ncloud.com/v1/...

    @Test
    public void callNcloudOcrApi() throws Exception {
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
        headers.set("X-OCR-SECRET", SECRET);

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


    @Test
    public void callNcloudOcrApiWithBase64() throws Exception {
        String resourcePath = "/img/XM3_REGIST1.jpg"; // src/main/resources/img/your_image.jpg
        String base64Image = encodeImageToBase64FromResource(resourcePath);

        Map<String, Object> imageMap = new HashMap<>();
        imageMap.put("format", "jpg");
        imageMap.put("name", "demo");
        imageMap.put("data", base64Image);

        Map<String, Object> requestJson = new HashMap<>();
        requestJson.put("images", List.of(imageMap));
        requestJson.put("requestId", UUID.randomUUID().toString());
        requestJson.put("version", "V2");
        requestJson.put("timestamp", System.currentTimeMillis());
        requestJson.put("lang", "ko"); // 한국어

        ObjectMapper objectMapper = new ObjectMapper();
        String payload = objectMapper.writeValueAsString(requestJson);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.set("X-OCR-SECRET", SECRET);

        HttpEntity<String> entity = new HttpEntity<>(payload, headers);

        RestTemplate restTemplate = new RestTemplate();
        ResponseEntity<String> response = restTemplate.exchange(
                apiUrl,
                HttpMethod.POST,
                entity,
                String.class
        );

        System.out.println("Status: " + response.getStatusCode());
        System.out.println("Body: " + response.getBody());
    }

    @Test
    public void callNcloudOcrApiWithBase64_2() throws Exception {
        // 1. 리소스 이미지 Base64 인코딩
        String resourcePath = "/img/XM3_REGIST1.jpg"; // src/main/resources/img/XM3_REGIST1.jpg
        String base64Image = encodeImageToBase64FromResource(resourcePath);

        // 2. OCR API 요청 바디 생성
        Map<String, Object> imageMap = new HashMap<>();
        imageMap.put("format", "jpg");
        imageMap.put("name", "demo");
        imageMap.put("data", base64Image);

        Map<String, Object> requestJson = new HashMap<>();
        requestJson.put("images", List.of(imageMap));
        requestJson.put("requestId", UUID.randomUUID().toString());
        requestJson.put("version", "V2");
        requestJson.put("timestamp", System.currentTimeMillis());
        requestJson.put("lang", "ko");

        ObjectMapper objectMapper = new ObjectMapper();
        String payload = objectMapper.writeValueAsString(requestJson);

        // 3. 헤더 세팅
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.set("X-OCR-SECRET", SECRET);

        HttpEntity<String> entity = new HttpEntity<>(payload, headers);

        // 4. API 호출
        RestTemplate restTemplate = new RestTemplate();
        ResponseEntity<String> response = restTemplate.exchange(
                apiUrl,
                HttpMethod.POST,
                entity,
                String.class
        );

        if (!response.getStatusCode().is2xxSuccessful() || response.getBody() == null) {
            // 실패 시 null 반환 또는 커스텀 예외 처리
            return;
        }

        // 5. OCR 응답 파싱
        JsonNode root = objectMapper.readTree(response.getBody());
        JsonNode fields = root.path("images").get(0).path("fields");
        String vin = null;
        String modelName = null;
        LocalDate registeredAt = null;

        // 6. 키워드 기반 우선 추출 (신뢰도 매우 높음)
        for (int i = 0; i < fields.size(); i++) {
            String text = fields.get(i).path("inferText").asText().replaceAll("\\s", "");

            // "차대번호", "대번호" 등의 키워드 확인 후 바로 다음 값 → VIN
            if ((text.contains("차대번호") || text.contains("대번호")) && vin == null) {
                if (i + 1 < fields.size()) {
                    String vinCandidate = fields.get(i + 1).path("inferText").asText().replaceAll("\\s", "");
                    if (vinCandidate.matches("^[A-Z0-9]{10,}$")) vin = vinCandidate;
                }
            }
            // "형식", "명칭", "차명", "명" 등 키워드로 모델명 추출
            if ((text.contains("형식") || text.contains("명칭") || text.equals("명") || text.contains("차명")) && modelName == null) {
                if (i + 1 < fields.size()) {
                    String nameCandidate = fields.get(i + 1).path("inferText").asText().replaceAll("\\s", "");
                    if (nameCandidate.matches("^[A-Z]{2,}\\d?$") || nameCandidate.matches("^[A-Z]{2,}\\d{1,2}$") || nameCandidate.matches("^[가-힣A-Z0-9]+$")) {
                        modelName = nameCandidate;
                    }
                }
            }
            // "최초등록일" 키워드 → 날짜 형식 파싱 (분리 필드 지원)
            if (text.contains("최초등록일") && registeredAt == null) {
                // 1) 한 필드에 "2020-05-04"처럼 붙어 있으면 바로 파싱
                for (int j = 1; j <= 3 && (i + j) < fields.size(); j++) {
                    String nextText = fields.get(i + j).path("inferText").asText().replaceAll("[^\\d]", "-").replaceAll("-+", "-");
                    if (nextText.matches("\\d{4}-\\d{2}-\\d{2}")) {
                        try {
                            registeredAt = LocalDate.parse(nextText, DateTimeFormatter.ofPattern("yyyy-MM-dd"));
                            break;
                        } catch (Exception e) {}
                    }
                    // 2) 분리 필드(예: "2020", "년 05", "월 04 일") 조합
                    if (j == 1 && nextText.matches("\\d{4}")) {
                        String year = nextText;
                        String month = (i + 2 < fields.size())
                                ? fields.get(i + 2).path("inferText").asText().replaceAll("[^\\d]", "")
                                : "01";
                        String day = (i + 3 < fields.size())
                                ? fields.get(i + 3).path("inferText").asText().replaceAll("[^\\d]", "")
                                : "01";
                        if (!month.isEmpty() && !day.isEmpty()) {
                            String formatted = String.format("%s-%02d-%02d", year, Integer.parseInt(month), Integer.parseInt(day));
                            try {
                                registeredAt = LocalDate.parse(formatted, DateTimeFormatter.ofPattern("yyyy-MM-dd"));
                                break;
                            } catch (Exception e) {}
                        }
                    }
                }
            }
        }

        // 7. Fallback: 키워드 기반으로 못 찾으면 패턴 기반 서브 추출
        if (vin == null || modelName == null || registeredAt == null) {
            for (int i = 0; i < fields.size(); i++) {
                String text = fields.get(i).path("inferText").asText().replaceAll("\\s", "");
                if (vin == null && text.matches("^[A-Z0-9]{10,}$")) vin = text;
                if (modelName == null && text.matches("^[A-Z]{2,}\\d?$")) modelName = text;
                if (registeredAt == null && text.matches("\\d{4}-\\d{2}-\\d{2}")) {
                    try {
                        registeredAt = LocalDate.parse(text, DateTimeFormatter.ofPattern("yyyy-MM-dd"));
                    } catch (Exception e) {}
                }
            }
        }

        // 8. 결과 VO 생성 및 반환/출력
        CarRegistrationOcrResponseVo res = CarRegistrationOcrResponseVo.builder()
                .vin(vin)
                .modelName(modelName)
                .registeredAt(registeredAt)
                .build();

        log.info("최종 OCR 결과: {}", res);
    }



    // Base64 인코딩 메서드
    public String encodeImageToBase64(String imagePath) throws Exception {
        File file = new File(imagePath);
        FileInputStream imageInFile = new FileInputStream(file);
        byte[] imageData = new byte[(int) file.length()];
        imageInFile.read(imageData);
        imageInFile.close();
        return Base64.getEncoder().encodeToString(imageData);
    }
    /** 리소스 파일을 Base64로 변환하는 메서드 */
    public String encodeImageToBase64FromResource(String resourcePath) throws Exception {
        try (InputStream in = getClass().getResourceAsStream(resourcePath)) {
            if (in == null) throw new IllegalArgumentException("리소스 파일 없음: " + resourcePath);
            byte[] imageData = in.readAllBytes();
            return Base64.getEncoder().encodeToString(imageData);
        }
    }

    @Test
    public void callNcloudOcrApiAndParseCarInfo() throws Exception {
        String resourcePath = "/img/XM3_REGIST1.jpg"; // src/main/resources/img/...
        String base64Image = encodeImageToBase64FromResource(resourcePath);

        Map<String, Object> imageMap = new HashMap<>();
        imageMap.put("format", "jpg");
        imageMap.put("name", "demo");
        imageMap.put("data", base64Image);

        Map<String, Object> requestJson = new HashMap<>();
        requestJson.put("images", List.of(imageMap));
        requestJson.put("requestId", UUID.randomUUID().toString());
        requestJson.put("version", "V2");
        requestJson.put("timestamp", System.currentTimeMillis());
        requestJson.put("lang", "ko"); // 한국어

        ObjectMapper objectMapper = new ObjectMapper();
        String payload = objectMapper.writeValueAsString(requestJson);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.set("X-OCR-SECRET", SECRET);

        HttpEntity<String> entity = new HttpEntity<>(payload, headers);
        RestTemplate restTemplate = new RestTemplate();

        ResponseEntity<String> response = restTemplate.exchange(
                apiUrl,
                HttpMethod.POST,
                entity,
                String.class
        );

        JsonNode root = objectMapper.readTree(response.getBody());
        JsonNode fields = root.path("images").get(0).path("fields");

        String modelName = null;
        String vin = null;
        String registrationDate = null;

        for (int i = 0; i < fields.size(); i++) {
            String text = fields.get(i).path("inferText").asText();

            // 모델명 (명 항목)
            if (text.equals("명") && i + 1 < fields.size()) {
                modelName = fields.get(i + 1).path("inferText").asText();
            }

            // VIN (대 번호 항목)
            if (text.contains("대") && text.contains("번호") && i + 1 < fields.size()) {
                String candidate = fields.get(i + 1).path("inferText").asText();
                if (candidate.matches("[A-HJ-NPR-Z0-9]{17}")) { // VIN 패턴
                    vin = candidate;
                }
            }

            // 최초등록일
            if (text.contains("최초등록일") && registrationDate == null) {
                for (int j = i + 1; j < Math.min(i + 5, fields.size()); j++) {
                    String candidate = fields.get(j).path("inferText").asText();
                    if (candidate.matches("\\d{4}[-년]\\s?\\d{1,2}[-월]\\s?\\d{1,2}")) {
                        registrationDate = candidate
                                .replace("년", "-")
                                .replace("월", "-")
                                .replace("일", "")
                                .replaceAll("\\s", "");
                        break;
                    }
                }
            }
        }

        System.out.println("모델명: " + modelName);
        System.out.println("VIN: " + vin);
        System.out.println("최초등록일: " + registrationDate);
    }



}
