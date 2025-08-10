package com.dolijo.moring.ocr;

import com.dolijo.moring.ai.vo.out.CarRegistrationOcrResponseVo;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.log4j.Log4j2;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;
import org.springframework.http.*;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestTemplate;

import java.nio.file.Files;
import java.time.LocalDate;
import java.util.*;

import static org.assertj.core.api.AssertionsForClassTypes.assertThat;


@Log4j2
public class ClovaCarRegistOcrCustomTemplateTest {
      // 예: https://api.ocr.ncloud.com/v1/...
    // TODO: 아래 3가지는 네가 실제 값으로 채워 넣어줘
    private static final String API_URL = "https://oqtnvjdj34.apigw.ntruss.com/custom/v1/45012/5b9efbaf3e28ac31277a8d058c52e420b7595dab45def89e86ee257bcb5fc052/infer"; // 예: https://.../custom/v1/xxxx/yyy/z
    private static final String SECRET = "SVJKakxsUEVnWmxiTlhsbHRoRkdQTlNTR1BQRVZJak8=";
    private static final long CAR_REGISTRATION_TEMPLATE_ID = 38526L; // 자동차등록증 템플릿 id
    private static final long PART_REPAIR_ESTIMATE = 38528L; // 배포된 템플릿 ID

    @Test
    @DisplayName("CLOVA Template OCR → CarRegistrationOcrResponseVo 매핑")
    void callTemplateOcrAndMapToVo() throws Exception {
        // 1) 이미지 로드
        ClassPathResource resource = new ClassPathResource("img/XM3_REGIST2.jpg");
        byte[] imageBytes = Files.readAllBytes(resource.getFile().toPath());

        // 2) message(JSON) 구성
        ObjectMapper om = new ObjectMapper();
        Map<String, Object> requestJson = Map.of(
                "images", List.of(
                        Map.of(
                                "format", "jpg",
                                "name", "demo",
                                "templateIds", List.of(CAR_REGISTRATION_TEMPLATE_ID)
                        )
                ),
                "requestId", UUID.randomUUID().toString(),
                "version", "V2",
                "timestamp", System.currentTimeMillis()
        );
        String messageJson = om.writeValueAsString(requestJson);

        // 3) 멀티파트 요청 바디
        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        body.add("message", messageJson);
        body.add("file", new org.springframework.core.io.ByteArrayResource(imageBytes) {
            @Override public String getFilename() { return "XM3_REGIST2.jpg"; }
        });

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);
        headers.set("X-OCR-SECRET", SECRET);

        HttpEntity<MultiValueMap<String, Object>> entity = new HttpEntity<>(body, headers);

        // 4) 호출
        RestTemplate restTemplate = new RestTemplate();
        ResponseEntity<String> response = restTemplate.exchange(API_URL, HttpMethod.POST, entity, String.class);
        assertThat(response.getStatusCode().is2xxSuccessful()).isTrue();

        // 5) 응답 파싱
        JsonNode root = om.readTree(response.getBody());
        JsonNode image0 = root.path("images").get(0);

        // 6) OCR 데이터 추출
        String vin = findFieldValueWithAliases(image0, List.of("vin", "차대번호", "vehicleId"));
        String modelName = findFieldValueWithAliases(image0, List.of("modelName", "모델명"));
        String registeredAtRaw = findFieldValueWithAliases(image0, List.of("registedAt", "registeredAt", "등록일", "최초등록일"));
        LocalDate registeredAt = parseToLocalDate(registeredAtRaw);

        // 7) VO 매핑
        CarRegistrationOcrResponseVo vo = CarRegistrationOcrResponseVo.builder()
                .vin(vin)
                .modelName(modelName)
                .registeredAt(registeredAt)
                .build();

        // 8) 결과 출력
        log.info("OCR 응답 VO: {}", vo);
    }

    /** 여러 별칭 중 처음 매칭되는 field.name의 inferText 반환 */
    private static String findFieldValueWithAliases(JsonNode imageNode, List<String> aliases) {
        for (JsonNode f : imageNode.path("fields")) {
            String name = f.path("name").asText();
            for (String alias : aliases) {
                if (name.equalsIgnoreCase(alias) || name.toLowerCase().contains(alias.toLowerCase())) {
                    return f.path("inferText").asText(null);
                }
            }
        }
        return null;
    }

    /** LocalDate 변환 (한글 날짜 포함) */
    private static LocalDate parseToLocalDate(String raw) {
        if (raw == null) return null;
        String cleaned = raw.replaceAll("\\s+", "")
                .replace("년", "-")
                .replace("월", "-")
                .replace("일", "")
                .replaceAll("-{2,}", "-");
        String[] parts = cleaned.split("-");
        if (parts.length >= 3) {
            int year = Integer.parseInt(parts[0]);
            int month = Integer.parseInt(parts[1]);
            int day = Integer.parseInt(parts[2]);
            return LocalDate.of(year, month, day);
        }
        return null;
    }

    @Test
    @DisplayName("CLOVA Template OCR → PART_REPAIR_ESTIMATE 템플릿 결과 System.out 출력")
    void callPartRepairEstimateTemplateAndPrint() throws Exception {
        // 1) 이미지 로드
        ClassPathResource resource = new ClassPathResource("img/PART_REPAIR_ESTIMATE.jpg");
        byte[] imageBytes = Files.readAllBytes(resource.getFile().toPath());

        // 2) message(JSON) 구성
        ObjectMapper om = new ObjectMapper();
        Map<String, Object> requestJson = Map.of(
                "images", List.of(
                        Map.of(
                                "format", "jpg",
                                "name", "demo",
                                "templateIds", List.of(PART_REPAIR_ESTIMATE)
                        )
                ),
                "requestId", UUID.randomUUID().toString(),
                "version", "V2",
                "timestamp", System.currentTimeMillis()
        );
        String messageJson = om.writeValueAsString(requestJson);

        // 3) 멀티파트 요청 바디
        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        body.add("message", messageJson);
        body.add("file", new org.springframework.core.io.ByteArrayResource(imageBytes) {
            @Override public String getFilename() { return "PART_REPAIR_ESTIMATE.jpg"; }
        });

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);
        headers.set("X-OCR-SECRET", SECRET);

        HttpEntity<MultiValueMap<String, Object>> entity = new HttpEntity<>(body, headers);

        // 4) 호출
        RestTemplate restTemplate = new RestTemplate();
        ResponseEntity<String> response = restTemplate.exchange(API_URL, HttpMethod.POST, entity, String.class);
        assertThat(response.getStatusCode().is2xxSuccessful()).isTrue();

        // 5) 응답 파싱 및 System.out 출력
        JsonNode root = om.readTree(response.getBody());
        JsonNode image0 = root.path("images").get(0);
        System.out.println("[PART_REPAIR_ESTIMATE 템플릿 OCR 결과]");
        for (JsonNode f : image0.path("fields")) {
            String name = f.path("name").asText();
            String inferText = f.path("inferText").asText();
            System.out.printf("%s : %s\n", name, inferText);
        }
    }

    @Test
    @DisplayName("CLOVA Template OCR → PART_REPAIR_ESTIMATE 템플릿 changedPartList 항목 분리 추출")
    void callPartRepairEstimateTemplateAndExtractChangedPartList() throws Exception {
        // 1) 이미지 로드
        ClassPathResource resource = new ClassPathResource("img/PART_REPAIR_ESTIMATE.jpg");
        byte[] imageBytes = Files.readAllBytes(resource.getFile().toPath());

        // 2) message(JSON) 구성
        ObjectMapper om = new ObjectMapper();
        Map<String, Object> requestJson = Map.of(
                "images", List.of(
                        Map.of(
                                "format", "jpg",
                                "name", "demo",
                                "templateIds", List.of(PART_REPAIR_ESTIMATE)
                        )
                ),
                "requestId", UUID.randomUUID().toString(),
                "version", "V2",
                "timestamp", System.currentTimeMillis()
        );
        String messageJson = om.writeValueAsString(requestJson);

        // 3) 멀티파트 요청 바디
        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        body.add("message", messageJson);
        body.add("file", new org.springframework.core.io.ByteArrayResource(imageBytes) {
            @Override public String getFilename() { return "PART_REPAIR_ESTIMATE.jpg"; }
        });

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);
        headers.set("X-OCR-SECRET", SECRET);

        HttpEntity<MultiValueMap<String, Object>> entity = new HttpEntity<>(body, headers);

        // 4) 호출
        RestTemplate restTemplate = new RestTemplate();
        ResponseEntity<String> response = restTemplate.exchange(API_URL, HttpMethod.POST, entity, String.class);
        assertThat(response.getStatusCode().is2xxSuccessful()).isTrue();

        // 5) 응답 파싱
        JsonNode root = om.readTree(response.getBody());
        JsonNode image0 = root.path("images").get(0);
        String changedPartListRaw = null;
        for (JsonNode f : image0.path("fields")) {
            String name = f.path("name").asText();
            if ("changedPartList".equals(name)) {
                changedPartListRaw = f.path("inferText").asText();
                break;
            }
        }
        if (changedPartListRaw != null) {
            // 줄바꿈, 쉼표, 기타 구분자로 분리
            List<String> changedParts = Arrays.stream(changedPartListRaw.split("[\\r\\n,·]+"))
                    .map(String::trim)
                    .filter(s -> !s.isEmpty())
                    .toList();
            System.out.println("[changedPartList 항목 추출 결과]");
            changedParts.forEach(System.out::println);
        } else {
            System.out.println("changedPartList 항목이 없습니다.");
        }
    }

}
