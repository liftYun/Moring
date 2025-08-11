package com.dolijo.moring.part.dto.in;

import lombok.*;

import java.time.LocalDateTime;
import java.util.List;

@Getter
@AllArgsConstructor
@Builder
public class RegisterPartChangeLogRequestDto {
    private String vin;
    private LocalDateTime changedAt;
    private List<Long> partIdList;
}
