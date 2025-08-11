package com.dolijo.moring.ai.service;

import com.dolijo.moring.ai.dto.out.OcrPartChangeLogExtractedDto;
import com.dolijo.moring.ai.dto.out.CarRegistrationOcrResponseDto;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.log4j.Log4j2;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.UUID;


@Service
@Log4j2
public class OcrService {
    // ✅ application.yml 에서 주입 (값은 네가 채워넣으면 됨)
    @Value("${ncloud.ocr.custom.api-url}")
    private String apiUrl;
    @Value("${ncloud.ocr.custom.secret}")
    private String secret;
    @Value("${ncloud.ocr.custom.car-registration.template-id}")
    private long carRegistrationTemplateId;
    @Value("${ncloud.ocr.custom.part-repair-estimate.template-id}")
    private List<Long> partRepairEstimateTemplateIds;

    private final ObjectMapper objectMapper = new ObjectMapper();

    /**
     * CLOVA Custom Template OCR 호출 후, 차량 등록증 정보를 VO 로 매핑
     */
    public CarRegistrationOcrResponseDto carRegistrationOcr(MultipartFile image) throws Exception {
        // 1) 요청 message(JSON) 구성 — 템플릿 ID 지정
        Map<String, Object> requestJson = Map.of(
                "images", List.of(
                        Map.of(
                                "format", guessFormat(image.getOriginalFilename()),
                                "name", safeFilename(image.getOriginalFilename()),
                                "templateIds", List.of(carRegistrationTemplateId)
                        )
                ),
                "requestId", UUID.randomUUID().toString(),
                "version", "V2",
                "timestamp", System.currentTimeMillis()
        );
        String messageJson = objectMapper.writeValueAsString(requestJson);

        // 2) 멀티파트 바디 구성: message + file
        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        body.add("message", messageJson);
        body.add("file", new ByteArrayResource(image.getBytes()) {
            @Override public String getFilename() {
                return safeFilename(image.getOriginalFilename());
            }
        });

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);
        headers.set("X-OCR-SECRET", secret);

        HttpEntity<MultiValueMap<String, Object>> entity = new HttpEntity<>(body, headers);

        // 3) 호출
        RestTemplate restTemplate = new RestTemplate();
        ResponseEntity<String> response = restTemplate.exchange(apiUrl, HttpMethod.POST, entity, String.class);

        if (!response.getStatusCode().is2xxSuccessful()) {
            log.warn("CLOVA OCR 호출 실패: status={}, body={}", response.getStatusCode(), response.getBody());
            throw new IllegalStateException("CLOVA OCR 호출 실패");
        }

        // 4) 응답 파싱
        JsonNode root = objectMapper.readTree(response.getBody());
        JsonNode image0 = root.path("images").get(0);

        // 5) 필드 추출
        String vin = findFieldValueWithAliases(image0, List.of("vin", "차대번호", "vehicleId"));
        String modelName = findFieldValueWithAliases(image0, List.of("modelName", "모델명", "model", "차종"));
        String registeredAtRaw = findFieldValueWithAliases(image0, List.of("registedAt", "registeredAt", "등록일", "최초등록일"));
        LocalDate registeredAt = parseToLocalDate(registeredAtRaw);

        return CarRegistrationOcrResponseDto.builder()
                .vin(vin)
                .modelName(modelName)
                .registeredAt(registeredAt)
                .build();
    }

    /**
     * CLOVA Custom Template OCR 호출 후, 차량 정기점검등록증(부품 정비 견적서)에서 vin, changedAt, partNameList 추출
     */
    public OcrPartChangeLogExtractedDto extractPartChangeLogFromEstimate(MultipartFile image) throws Exception {
        if (partRepairEstimateTemplateIds == null || partRepairEstimateTemplateIds.isEmpty()) {
            throw new IllegalStateException("No template ids configured for part-repair-estimate.template-id");
        }
        // 1) 요청 message(JSON) 구성 — 템플릿 ID 지정
        Map<String, Object> requestJson = Map.of(
                "images", List.of(
                        Map.of(
                                "format", guessFormat(image.getOriginalFilename()),
                                "name", safeFilename(image.getOriginalFilename()),
                                "templateIds", partRepairEstimateTemplateIds
                        )
                ),
                "requestId", UUID.randomUUID().toString(),
                "version", "V2",
                "timestamp", System.currentTimeMillis()
        );


        String messageJson = objectMapper.writeValueAsString(requestJson);

        // 2) 멀티파트 바디 구성: message + file
        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        body.add("message", messageJson);
        body.add("file", new ByteArrayResource(image.getBytes()) {
            @Override public String getFilename() {
                return safeFilename(image.getOriginalFilename());
            }
        });

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);
        headers.set("X-OCR-SECRET", secret);

        HttpEntity<MultiValueMap<String, Object>> entity = new HttpEntity<>(body, headers);

        // 3) 호출
        RestTemplate restTemplate = new RestTemplate();
        ResponseEntity<String> response = restTemplate.exchange(apiUrl, HttpMethod.POST, entity, String.class);
        if (!response.getStatusCode().is2xxSuccessful()) {
            throw new IllegalStateException("OCR API 호출 실패: " + response.getStatusCode());
        }

        // 4) 응답 파싱 및 추출
        JsonNode root = objectMapper.readTree(response.getBody());
        JsonNode image0 = root.path("images").get(0);
        String vin = null;
        String changedAtRaw = null;
        String changedPartListRaw = null;
        for (JsonNode f : image0.path("fields")) {
            String name = f.path("name").asText();
            if ("changedAt".equalsIgnoreCase(name)) changedAtRaw = f.path("inferText").asText(null);
            if ("changedPartList".equalsIgnoreCase(name)) changedPartListRaw = f.path("inferText").asText(null);
        }
        // 날짜 파싱 (예: 2025 년 04 월 11 일)
        LocalDate changedAt = null;
        if (changedAtRaw != null) {
            String cleaned = changedAtRaw.replaceAll("\\s+", "")
                    .replace("년", "-")
                    .replace("월", "-")
                    .replace("일", "")
                    .replaceAll("-{2,}", "-");
            try {
                changedAt = LocalDate.parse(cleaned, DateTimeFormatter.ofPattern("yyyy-M-d"));
            } catch (Exception e) {
                // fallback: yyyy-MM-dd
                try { changedAt = LocalDate.parse(cleaned); } catch (Exception ignore) {}
            }
        }
        List<String> partNameList = new java.util.ArrayList<>();
        if (changedPartListRaw != null) {
            partNameList = Arrays.stream(changedPartListRaw.split("[\\r\\n,·]+"))
                    .map(String::trim)
                    .filter(s -> !s.isEmpty())
                    .toList();
        }
        return OcrPartChangeLogExtractedDto.builder()
                .changedAt(changedAt == null ? null : changedAt.atStartOfDay())
                .partNameList(partNameList)
                .build();
    }



    // ======== 유틸 메서드========

    /** 템플릿 필드 name 이 여러 변형으로 들어올 수 있어 별칭 기반으로 탐색 */
    private static String findFieldValueWithAliases(JsonNode imageNode, List<String> aliases) {
        // 1) 정확 일치(대소문자 무시)
        for (JsonNode f : imageNode.path("fields")) {
            String name = f.path("name").asText();
            for (String alias : aliases) {
                if (name.equalsIgnoreCase(alias)) {
                    return f.path("inferText").asText(null);
                }
            }
        }
        // 2) 포함 매칭(여유롭게)
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

    /** "2020 년 05 월 04 일" → "2020-05-04" → LocalDate */
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
            int month = Integer.parseInt(parts[1].length() == 1 ? "0" + parts[1] : parts[1]);
            int day = Integer.parseInt(parts[2].length() == 1 ? "0" + parts[2] : parts[2]);
            return LocalDate.of(year, month, day);
        }
        return null;
    }

    /** 파일명에서 확장자 추정 → format 값으로 사용(jpg/png 등) */
    private static String guessFormat(String filename) {
        if (filename == null) return "jpg";
        String lower = filename.toLowerCase();
        if (lower.endsWith(".png")) return "png";
        if (lower.endsWith(".jpeg")) return "jpeg";
        if (lower.endsWith(".webp")) return "webp";
        return "jpg";
    }
    /** null/공백 방지용 파일명 보정 */
    private static String safeFilename(String original) {
        if (original == null || original.isBlank()) return "upload.jpg";
        return original;
    }




}
