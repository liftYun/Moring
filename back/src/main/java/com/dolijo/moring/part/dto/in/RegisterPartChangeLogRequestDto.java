package com.dolijo.moring.part.dto.in;

import lombok.*;

import java.time.LocalDateTime;

@Getter
@AllArgsConstructor
@Builder
public class RegisterPartChangeLogRequestDto {
    private String vin;
    private Long partId;
    private LocalDateTime createdAt;
}
