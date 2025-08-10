package com.dolijo.moring.ai.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Log4j2
public class SafetyAskService {

    @Value("${prompt.safety-prompt}")
    private String safetyPrompt;
    @Qualifier("gmsChatClientBuilder")
    private final ChatClient.Builder chatBuilder;

    public String ask(String userInput) {
        return chatBuilder.build()
                .prompt()
                .system(safetyPrompt)
                .user(userInput)
                .call()
                .content();
    }
}
