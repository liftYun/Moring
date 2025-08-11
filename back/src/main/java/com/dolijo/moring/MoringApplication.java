package com.dolijo.moring;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;


@SpringBootApplication(exclude = {
		org.springframework.ai.model.openai.autoconfigure.OpenAiChatAutoConfiguration.class,
		org.springframework.ai.model.openai.autoconfigure.OpenAiImageAutoConfiguration.class,
		org.springframework.ai.model.openai.autoconfigure.OpenAiModerationAutoConfiguration.class,
		org.springframework.ai.model.openai.autoconfigure.OpenAiEmbeddingAutoConfiguration.class,
		org.springframework.ai.model.openai.autoconfigure.OpenAiAudioSpeechAutoConfiguration.class,
		org.springframework.ai.model.openai.autoconfigure.OpenAiAudioTranscriptionAutoConfiguration.class
})
public class MoringApplication {

	public static void main(String[] args) {
		SpringApplication.run(MoringApplication.class, args);
	}

}
