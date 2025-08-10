package com.dolijo.moring.ai.controller;

import com.dolijo.moring.ai.dto.out.OcrPartChangeLogExtractedDto;
import com.dolijo.moring.ai.service.AiService;
import com.dolijo.moring.ai.service.OcrService;
import com.dolijo.moring.ai.dto.out.CarRegistrationOcrResponseDto;
import com.dolijo.moring.ai.vo.out.CarRegistrationOcrResponseVo;
import com.dolijo.moring.common.base.BaseResponse;
import com.dolijo.moring.common.base.BaseResponseStatus;
import com.dolijo.moring.common.exception.BaseException;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/AI")
@Tag(name = "AI", description = "AI 관련 API")
@Log4j2
public class AIController {
    private final AiService aiService;
    private final OcrService ocrService;
    private static final int MAX_IMAGE_SIZE = 2 * 1024 * 1024; // 최대 이미지 크기 (MB)

    @PostMapping(
            value = "/car-registration",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE,
            produces = MediaType.APPLICATION_JSON_VALUE
    )
    @Operation(summary = "차량등록증 OCR", description = "차량등록증을 OCR로 인식하여 차량 정보를 추출합니다. 이미지 파일을 업로드해야 합니다. (2MB 이하, 이미지 형식만 허용)")
    public BaseResponse<CarRegistrationOcrResponseVo> ocrCarRegistration(
            @RequestPart("image") MultipartFile image
    ) throws Exception {
        validateImageFile(image, MAX_IMAGE_SIZE); // 2MB
        // 서비스는 기존대로 DTO 반환
        CarRegistrationOcrResponseDto dto = ocrService.carRegistrationOcr(image);
        return BaseResponse.of(CarRegistrationOcrResponseVo.from(dto));
    }

    @PostMapping(
            value = "/part-repair-estimate-ocr",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE,
            produces = MediaType.APPLICATION_JSON_VALUE
    )
    @Operation(summary = "부품 정비 견적서 OCR", description = "부품 정비 견적서 이미지를 업로드하면 교환 부품명 리스트, VIN, 교환일시를 추출합니다.")
    public BaseResponse<OcrPartChangeLogExtractedDto> ocrPartRepairEstimate(
            @RequestPart("image") MultipartFile image
    ) throws Exception {
        validateImageFile(image, MAX_IMAGE_SIZE);
        log.info("[부품 정비 견적서 OCR 요청] 파일명: {}", image.getOriginalFilename());
        OcrPartChangeLogExtractedDto result = ocrService.extractPartChangeLogFromEstimate(image);
        log.info("[부품 정비 견적서 OCR 결과] changedAt: {}, partNameList: {}",  result.getChangedAt(), result.getPartNameList());
        return BaseResponse.of(result);
    }

    /**
     * 이미지 파일 유효성 검사 (용량, 타입, null 등)
     */
    private void validateImageFile(MultipartFile image, long maxSize) {
        if (image == null || image.isEmpty()) {
            throw new BaseException(BaseResponseStatus.IMAGE_FILE_EMPTY);
        }
        if (image.getSize() > maxSize) {
            throw new BaseException(BaseResponseStatus.IMAGE_FILE_SIZE_EXCEEDED);
        }
        if (image.getContentType() == null || !image.getContentType().startsWith("image/")) {
            throw new BaseException(BaseResponseStatus.IMAGE_FILE_TYPE_INVALID);
        }
    }

    @PostMapping("/ask")
    @Operation(summary = "AI 안전 질문", description = "AI에게 안전 관련 질문을 합니다. 프롬프트를 입력하면 AI가 답변을 반환합니다.")
    public BaseResponse<String> ask(
            @RequestBody String prompt) {
        return BaseResponse.of(aiService.safetyAsk(prompt));
    }


}
