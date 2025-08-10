package com.dolijo.moring.ocr;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;
import org.springframework.http.*;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestTemplate;

import java.nio.file.Files;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

import static org.assertj.core.api.Assertions.assertThat;

public class ClovaPartRepairEstimateMultiTemplateTest {

    // ✅ 네가 실제 값으로 바꿔 넣기

    private static final String API_URL = "https://oqtnvjdj34.apigw.ntruss.com/custom/v1/45012/5b9efbaf3e28ac31277a8d058c52e420b7595dab45def89e86ee257bcb5fc052/infer"; // 예: https://.../custom/v1/xxxx/yyy/z
    private static final String SECRET = "SVJKakxsUEVnWmxiTlhsbHRoRkdQTlNTR1BQRVZJak8=";
    // ✅ yml 예: part-repair-estimate.template-id: [38528, 38530]
    private static final List<Long> TEMPLATE_IDS = Arrays.asList(38528L, 38530L);

    @Test
    @DisplayName("CLOVA Template OCR - 정비/점검 견적서(다중 템플릿 자동 매칭) 파싱")
    void callPartRepairEstimateTemplatesAndParse() throws Exception {
        // 1) 테스트 이미지 로드 (리소스 경로는 네 파일로 교체)
        ClassPathResource resource = new ClassPathResource("img/PART_REPAIR_ESTIMATE.jpg");
        byte[] imageBytes = Files.readAllBytes(resource.getFile().toPath());

        // 2) message(JSON) 구성 — ⭐ templateIds 여러 개 전달
        ObjectMapper om = new ObjectMapper();
        Map<String, Object> requestJson = Map.of(
                "images", List.of(
                        Map.of(
                                "format", guessFormat(resource.getFilename()),
                                "name",   resource.getFilename(),
                                "templateIds", TEMPLATE_IDS
                        )
                ),
                "requestId", UUID.randomUUID().toString(),
                "version", "V2",
                "timestamp", System.currentTimeMillis()
        );
        String messageJson = om.writeValueAsString(requestJson);

        // 3) multipart/form-data: message + file
        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        body.add("message", messageJson);
        body.add("file", new org.springframework.core.io.ByteArrayResource(imageBytes) {
            @Override public String getFilename() { return resource.getFilename(); }
        });

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);
        headers.set("X-OCR-SECRET", SECRET);

        HttpEntity<MultiValueMap<String, Object>> entity = new HttpEntity<>(body, headers);

        // 4) 호출
        RestTemplate restTemplate = new RestTemplate();
        ResponseEntity<String> response = restTemplate.exchange(API_URL, HttpMethod.POST, entity, String.class);
        assertThat(response.getStatusCode().is2xxSuccessful())
                .as("CLOVA OCR 호출 실패: %s", response.getBody())
                .isTrue();

        // 5) 응답 파싱
        JsonNode root = om.readTree(response.getBody());
        JsonNode image0 = root.path("images").get(0);

        String matchedName = image0.path("matchedTemplate").path("name").asText(null);
        long   matchedId   = image0.path("matchedTemplate").path("id").asLong(0);
        System.out.printf("MatchedTemplate -> id=%d, name=%s%n", matchedId, matchedName);

        // 6) 필드 추출 (별칭 포함)
        String changedAtRaw = findFieldValueWithAliases(image0, List.of("changedAt", "교체일", "정비일", "점검일"));
        String partListRaw  = findFieldValueWithAliases(image0, List.of("changedPartList", "교체부품목록", "부품목록"));

        LocalDate changedAt = parseToLocalDate(changedAtRaw);
        List<String> partNameList = splitPartNames(partListRaw);

        // 7) 출력/검증
        System.out.println("changedAt(raw): " + changedAtRaw + " -> " + changedAt);
        System.out.println("partNameList  : " + partNameList);

        // (선택) 간단 검증
        assertThat(matchedId).isIn(TEMPLATE_IDS);
        assertThat(partNameList).isNotNull();
    }

    // ===== 유틸 =====

    /** 템플릿 필드 name 이 여러 변형으로 들어올 수 있어 별칭 기반으로 탐색 (정확→부분 매칭) */
    private static String findFieldValueWithAliases(JsonNode imageNode, List<String> aliases) {
        // 정확 일치(대소문자 무시)
        for (JsonNode f : imageNode.path("fields")) {
            String name = f.path("name").asText();
            for (String alias : aliases) {
                if (name.equalsIgnoreCase(alias)) {
                    return f.path("inferText").asText(null);
                }
            }
        }
        // 포함 매칭(여유롭게)
        for (JsonNode f : imageNode.path("fields")) {
            String name = f.path("name").asText();
            for (String alias : aliases) {
                if (name.toLowerCase().contains(alias.toLowerCase())) {
                    return f.path("inferText").asText(null);
                }
            }
        }
        return null;
    }

    /** "2025 년 04 월 11 일" / "2025-4-1" 등 → LocalDate */
    private static LocalDate parseToLocalDate(String raw) {
        if (raw == null) return null;
        String cleaned = raw.replaceAll("\\s+", "")
                .replace("년", "-")
                .replace("월", "-")
                .replace("일", "")
                .replaceAll("-{2,}", "-");
        // 우선 yyyy-M-d 패턴 시도
        try {
            return LocalDate.parse(cleaned, DateTimeFormatter.ofPattern("yyyy-M-d"));
        } catch (Exception ignore) {}
        // fallback: ISO yyyy-MM-dd
        try {
            return LocalDate.parse(cleaned);
        } catch (Exception ignore) {}
        return null;
    }

    /** 부품 목록 문자열 → 리스트 (개행/쉼표/중점 구분자 처리) */
    private static List<String> splitPartNames(String raw) {
        if (raw == null || raw.isBlank()) return List.of();
        return Arrays.stream(raw.split("[\\r\\n,·]+"))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .distinct()
                .collect(Collectors.toList());
    }

    /** 파일 확장자 기반 포맷 추정 */
    private static String guessFormat(String filename) {
        if (filename == null) return "jpg";
        String lower = filename.toLowerCase();
        if (lower.endsWith(".png"))  return "png";
        if (lower.endsWith(".jpeg")) return "jpeg";
        if (lower.endsWith(".webp")) return "webp";
        if (lower.endsWith(".jpg"))  return "jpg";
        return "jpg";
    }
}
