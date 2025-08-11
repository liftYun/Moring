package com.dolijo.moring.ai.vo.out;

import lombok.*;
import java.time.LocalDateTime;
import java.util.List;
import com.dolijo.moring.ai.dto.out.PartIdResolveResponseDto;

@Getter
@AllArgsConstructor
@Builder
public class PartIdResolveResponseVo {
    private final LocalDateTime changedAt;
    private final List<Long> partIdList;

    public static PartIdResolveResponseVo from(PartIdResolveResponseDto dto) {
        return PartIdResolveResponseVo.builder()
                .changedAt(dto.getChangedAt())
                .partIdList(dto.getPartIdList())
                .build();
    }
}
