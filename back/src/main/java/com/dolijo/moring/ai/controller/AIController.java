package com.dolijo.moring.ai.controller;

import com.dolijo.moring.ai.service.AiService;
import com.dolijo.moring.ai.vo.out.CarRegistrationOcrResponseVo;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/AI")
@Tag(name = "AI", description = "AI 관련 API")
@Log4j2
public class AIController {
    private final AiService ocrService;

//    @PostMapping(value = "/car-registration-ocr",
//            consumes = MediaType.APPLICATION_FORM_URLENCODED_VALUE,
//            produces = MediaType.APPLICATION_JSON_VALUE)
@PostMapping(value = "/car-registration-ocr", consumes = "multipart/form-data")
public ResponseEntity<CarRegistrationOcrResponseVo> ocrCarRegistration(@RequestParam("image") MultipartFile image) throws Exception {
    System.out.println("111!!");
    long maxSize = 2 * 1024 * 1024; // 2MB
    if (image.getSize() > maxSize) {
        System.out.println("이미지 크기가 너무 큽니다. 2MB 이하로 업로드 해주세요.");
        return null;
    }
    System.out.println("222!!");
    CarRegistrationOcrResponseVo result = ocrService.carRegistrationOcr(image);
    return ResponseEntity.ok(result);
}

    @GetMapping("/ask")
    public ResponseEntity<String> ask(@RequestParam("prompt") String prompt) {
        String result = ocrService.ask(prompt);
        return ResponseEntity.ok(result);
    }
}
