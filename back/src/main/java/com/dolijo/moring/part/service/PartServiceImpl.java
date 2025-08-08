package com.dolijo.moring.part.service;

import com.dolijo.moring.car.entity.Car;
import com.dolijo.moring.car.repository.CarRepository;
import com.dolijo.moring.common.base.BaseResponseStatus;
import com.dolijo.moring.common.exception.BaseException;
import com.dolijo.moring.part.dto.in.RegisterPartChangeLogRequestDto;
import com.dolijo.moring.part.dto.in.RegisterPartRequestDto;
import com.dolijo.moring.part.dto.out.PartResponseDto;
import com.dolijo.moring.part.dto.out.PartStatusListDto;
import com.dolijo.moring.part.dto.out.PartStatusListResponseDto;
import com.dolijo.moring.part.entity.Part;
import com.dolijo.moring.part.entity.PartChangeLog;
import com.dolijo.moring.part.repository.PartChangeLogRepository;
import com.dolijo.moring.part.repository.PartDslRepository;
import com.dolijo.moring.part.repository.PartRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.apache.juli.logging.Log;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

@Service
@Transactional(readOnly = true)
@RequiredArgsConstructor
@Log4j2
public class PartServiceImpl implements PartService {

    private final PartRepository partRepository;
    private final CarRepository carRepository;
    private final PartChangeLogRepository partChangeLogRepository;
    private final PartDslRepository partDslRepository;

    @Transactional
    @Override
    public Long registerPart(RegisterPartRequestDto requestDto) {
        log.info(requestDto);
        // 중복 등록 정책이 필요하다면 여기에 existsByNameKoAndNameEn 등 체크 추가
        Part part = Part.builder()
                .nameKo(requestDto.getNameKo())
                .nameEn(requestDto.getNameEn())
                .recommendedCycleMonths(requestDto.getRecommendedCycleMonths())
                .recommendedCycleKm(requestDto.getRecommendedCycleKm() == null ? 0 : requestDto.getRecommendedCycleKm())
                .type(requestDto.getType())
                .description(requestDto.getDescription())
                .build();
        partRepository.save(part);
        return part.getId();
    }

    @Override
    public List<PartResponseDto> getAllParts() {
        return partRepository.findAll()
                .stream()
                .map(PartResponseDto::from)
                .collect(Collectors.toList());
    }

    @Transactional
    @Override
    public Long registerPartChangeLog(RegisterPartChangeLogRequestDto dto) {
        Part part = partRepository.findById(dto.getPartId())
                .orElseThrow(() -> new BaseException(BaseResponseStatus.NO_EXIST_PART));

        Car car = carRepository.findByVin(dto.getVin())
                .orElseThrow(() -> new BaseException(BaseResponseStatus.NO_EXIST_CAR));

        return  partChangeLogRepository.save(
                PartChangeLog.builder()
                        .part(part)
                        .car(car)
                        .changedAt(dto.getChangedAt())
                        .build()).getId();
    }

    @Override
    public List<PartStatusListResponseDto> getPartStatusList(String vin) {
        Car car = carRepository.findByVin(vin)
                .orElseThrow(() -> new BaseException(BaseResponseStatus.NO_EXIST_CAR));
        List<PartStatusListDto> dtos = partDslRepository.findPartStatusListByCarId(car.getId());

        LocalDate today = LocalDate.now();
        List<PartStatusListResponseDto> result = new ArrayList<>();

        /**
            PartStatusListDto 부품리스트로 사용자가 차량 부품 교체 등록내역이 없다면
            dto의 lastChange은 null 이다.
         */
        for (PartStatusListDto dto : dtos) {
            String nameEn = dto.getNameEn();
            // 차량의 각 부품 교체일
            LocalDateTime lastChange = dto.getLastChange();
            // 각 부품의 권장 교체주기
            Integer cycleMonths = dto.getRecommendedCycleMonths();
            // 교체 이력이 없거나, 권장 주기가 잘못된 경우: 사용률 0%, 마감일 없음
            if (lastChange == null || cycleMonths == null || cycleMonths <= 0) {
                result.add(
                        PartStatusListResponseDto.builder()
                                .partId(dto.getPartId())
                                .nameEn(nameEn)
                                .percentUsed(0)
                                .dueDate(null)
                                .build()
                );
                continue;
            }

            // 마지막 교체일을 LocalDate로 변환 (시간 필요없음)
            LocalDate lastChangeDate = lastChange.toLocalDate();
            // dueDate: 마지막 교체일 + 권장 교체주기(월)
            LocalDate dueDate = lastChangeDate.plusMonths(cycleMonths);

            // 경과 일수 = 오늘 - 마지막 교체일
            long passedDays = ChronoUnit.DAYS.between(lastChangeDate, today);
            // 총 주기 일수 = 권장 교체주기(월) × 30일 (편의상 1달 30일로 계산)
            long totalDays = cycleMonths * 30L;

            // 사용률(%) = (경과일/총주기일) × 100, 0~100 사이로 클램핑
            int percent = (int) Math.min(100, Math.max(0, (passedDays * 100 / totalDays)));
            result.add(
                    PartStatusListResponseDto.builder()
                            .partId(dto.getPartId())
                            .nameEn(nameEn)
                            .percentUsed(percent)
                            .dueDate(dueDate)
                            .build()
            );
        }
        return result;
    }


}
