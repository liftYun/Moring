package com.dolijo.moring.ai.dto.system;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.*;

import java.util.List;

@Getter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@JsonIgnoreProperties(ignoreUnknown = true) // JSON 직렬화/역직렬화 시 알 수 없는 속성을 무시합니다.

public class LlmPartIdsOnly {
    @JsonProperty("partIdList")
    private List<Long> partIdList;
}
