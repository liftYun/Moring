package com.dolijo.moring.sms;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.extern.log4j.Log4j2;
import net.nurigo.sdk.NurigoApp;
import net.nurigo.sdk.message.model.Message;
import net.nurigo.sdk.message.request.SingleMessageSendingRequest;
import net.nurigo.sdk.message.response.SingleMessageSentResponse;
import net.nurigo.sdk.message.service.DefaultMessageService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;

@RestController
@RequestMapping("/api/v1/sms")
@Log4j2
@Tag(name = "SMS", description = "SMS API")
public class SmsController {

    private static SecureRandom secureRandom;
    static {
        try {
            secureRandom = SecureRandom.getInstanceStrong();
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SecureRandom Instance not created...", e);
        }
    }

    private final DefaultMessageService messageService;
    private final String from; // ← yml에서 주입한 발신번호 사용

    /** 생성자 주입: API 키/시크릿 + from */
    public SmsController(
            @Value("${coolsms.api-key}") String apiKey,
            @Value("${coolsms.api-secret}") String apiSecret,
            @Value("${coolsms.from}") String from
    ) {
        this.messageService = NurigoApp.INSTANCE.initialize(apiKey, apiSecret, "https://api.coolsms.co.kr");
        this.from = from;
    }

    private String createNumberKey() {
        int randomNumber = 100000 + secureRandom.nextInt(900000);
        log.warn("randomNumber : {}", randomNumber);
        return String.valueOf(randomNumber);
    }

    @PostMapping("/send")
    @Operation(summary = "Send SMS", description = "Send a single SMS message with a randomly generated number key.")
    public ResponseEntity<String> sendOne() {
        String numberKey = createNumberKey();

        Message message = new Message();
        message.setFrom(from);              // ← yml에서 주입된 승인된 발신번호 사용
        message.setTo("01025859452");       // 수신번호(임시)
        message.setText("[SMS] 인증번호: " + numberKey + "를 입력하세요.");

        log.warn("Sending message: {}", message.getText());

        SingleMessageSentResponse response =
                this.messageService.sendOne(new SingleMessageSendingRequest(message));
        log.warn("response: {}", response);

        return ResponseEntity.ok(
                "SMS sent. messageId=" + response.getMessageId() +
                        ", groupId=" + response.getGroupId()
        );
    }
}
