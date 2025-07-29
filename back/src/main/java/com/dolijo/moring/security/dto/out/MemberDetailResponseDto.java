package com.dolijo.moring.security.dto.out;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.ToString;

@Getter
@AllArgsConstructor
@NoArgsConstructor
@ToString
public class MemberDetailResponseDto {
    private Long id;
    private String nickname;
}
