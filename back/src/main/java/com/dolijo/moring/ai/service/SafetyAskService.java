package com.dolijo.moring.ai.service;

import com.dolijo.moring.ai.tools.SafeDrivingTipTool;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.document.Document;
import org.springframework.ai.vectorstore.SearchRequest;
import org.springframework.ai.vectorstore.VectorStore;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Log4j2
public class SafetyAskService {

    @Value("${prompt.safety-prompt}")
    private String safetyPrompt;
    @Qualifier("gmsChatClientBuilder")
    private final ChatClient.Builder chatBuilder;

    private final SafeDrivingTipTool safeDrivingTipTool;

    @Qualifier("moringVectorStore")
    private VectorStore vectorStore;

    private static final int LIMIT_TOKEN_SIZE = 5000; // 최대 토큰 크기 설정

    public String ask(String userInput) {
        return chatBuilder.build()
                .prompt()
                .system(safetyPrompt)
                .tools(safeDrivingTipTool) // 안전 운전 관련 RAG 툴을 사용! 유저 질문에 따라 필요할때만 자동 호출
                .user(userInput)
                .call()
                .content();
    }

}
