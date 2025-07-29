package com.dolijo.moring.security.dto.out;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@AllArgsConstructor
@NoArgsConstructor
@Builder
public class RegistResponseDto {
    private Long id;
    private String nickname;
    private String userEmail;
}