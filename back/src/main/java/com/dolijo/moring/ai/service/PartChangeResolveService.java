package com.dolijo.moring.ai.service;

import com.dolijo.moring.ai.dto.out.OcrPartChangeLogExtractedDto;
import com.dolijo.moring.ai.dto.out.PartIdResolveResponseDto;

import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

/**
 * 이미지(견적서) -> OCR -> LLM 매칭(툴 호출 포함) -> 최종 ID 리스트
 * 파이프라인 오케스트레이션 서비스
 */
@Service
@RequiredArgsConstructor
@Log4j2
public class PartChangeResolveService {

    private final OcrService ocrService;
    private final AiService aiService;
    // ↑ mapToIds(OcrPartChangeLogExtractedDto) 를 가진 AI 서비스 (네가 만든 그 클래스 이름에 맞춰 주입)


    /**
     * 컨트롤러는 이 메서드만 호출하면 됨.
     * 1) OCR로 changedAt, partNameList 추출
     * 2) LLM+ToolCalling으로 partIdList 매칭
     */
    public PartIdResolveResponseDto resolveFromImage(MultipartFile image) throws Exception {
        // 1) OCR
        OcrPartChangeLogExtractedDto ocr = ocrService.extractPartChangeLogFromEstimate(image);
        // OcrPartChangeLogExtractedDto 로깅
        log.info("1차로 clova OCR Result: {}", ocr);

        // 2) LLM 매칭 (내부에서 Tool(findPartCandidatesByName) 호출)
        return aiService.resolvePartIdsWithLlm(ocr);
    }



}
