package com.dolijo.moring.part.service;


import com.dolijo.moring.part.dto.in.RegisterPartChangeLogRequestDto;
import com.dolijo.moring.part.dto.in.RegisterPartRequestDto;
import com.dolijo.moring.part.dto.out.PartResponseDto;
import com.dolijo.moring.part.dto.out.PartStatusListResponseDto;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;



public interface PartService {

    Long registerPart(RegisterPartRequestDto requestDto);


    List<PartResponseDto> getAllParts();

    Long registerPartChangeLog(RegisterPartChangeLogRequestDto dto);

    List<PartStatusListResponseDto> getPartStatusList(String vin);

}
