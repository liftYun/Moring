package com.dolijo.moring.batch.job;

import com.dolijo.moring.batch.dto.CarInspectionAlertBatchDto;
import com.dolijo.moring.batch.dto.FCMNotificationRequestDto;
import com.dolijo.moring.batch.dto.NotificationBatchDto;
import com.dolijo.moring.common.base.BaseResponseStatus;
import com.dolijo.moring.common.exception.BaseException;
import com.dolijo.moring.notifycation.service.PushService;
import com.dolijo.moring.notifycation.valueobject.NotificationDetailType;
import com.dolijo.moring.notifycation.valueobject.NotificationType;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.batch.core.Job;
import org.springframework.batch.core.JobExecutionListener;
import org.springframework.batch.core.Step;

import org.springframework.batch.core.job.builder.JobBuilder;
import org.springframework.batch.core.step.builder.StepBuilder;
import org.springframework.batch.item.ItemProcessor;
import org.springframework.batch.item.database.BeanPropertyItemSqlParameterSourceProvider;
import org.springframework.batch.item.database.JdbcBatchItemWriter;
import org.springframework.batch.item.database.JdbcPagingItemReader;
import org.springframework.batch.item.database.Order;
import org.springframework.batch.item.database.builder.JdbcBatchItemWriterBuilder;
import org.springframework.batch.item.database.builder.JdbcPagingItemReaderBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.Async;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.batch.core.repository.JobRepository;

import javax.sql.DataSource;
import java.sql.ResultSet;
import java.util.Map;

/**
 * 차량 정기점검일 임박 알림 배치
 * - 정기점검일이 30일 이하로 남은 차량에 대해 알림을 생성
 * - 30, 15, 7, 3, 1, 당일에 해당하면 알림 발송
 * - 알림 전송 실패 시 DLQ로 재시도
 */
@Configuration
@EnableAsync
@RequiredArgsConstructor
@Log4j2
public class CarInspectionAlertBatch {
    private final JobRepository jobRepository;
    private final PlatformTransactionManager platformTransactionManager;
    private final DataSource dataSource;
    private final JobExecutionListener jobExecutionListener;
    private final PushService pushService;

    // 배치 작업 정의
    @Bean
    public Job carInspectionAlertJob() {
        return new JobBuilder("carInspectionAlertJob", jobRepository)
                .listener(jobExecutionListener)
                .start(expirePastInspectionStep())      // 만료 처리 선실행
                .next(carInspectionAlertStep())         // 알림 Step 실행
                .build();
    }

    @Bean
    public Step expirePastInspectionStep() {
        return new StepBuilder("expirePastInspectionStep", jobRepository)
                .tasklet((contribution, chunkContext) -> {
                    String sql = "UPDATE car_inspection_log " +
                            "SET inspection_status = 'EXPIRED' " +
                            "WHERE inspection_date < CURDATE() " +
                            "AND inspection_status = 'PENDING'";
                    dataSource.getConnection().createStatement().executeUpdate(sql);
                    log.info("[정기점검 만료 처리] 오늘 이전 날짜는 EXPIRED 처리 완료");
                    return org.springframework.batch.repeat.RepeatStatus.FINISHED;
                }, platformTransactionManager)
                .build();
    }

    // Step 정의
    @Bean
    public Step carInspectionAlertStep() {
        return new StepBuilder("carInspectionAlertStep", jobRepository)
                .<CarInspectionAlertBatchDto, NotificationBatchDto>chunk(10, platformTransactionManager)
                .reader(carInspectionAlertReader())
                .processor(carInspectionAlertProcessor())
                .writer(carInspectionAlertWriter())
                .build();
    }

    // 정기점검일이 60일 이하로 남은 차량 + 회원 정보까지 조인해서 조회
    @Bean
    public JdbcPagingItemReader<CarInspectionAlertBatchDto> carInspectionAlertReader() {
        return new JdbcPagingItemReaderBuilder<CarInspectionAlertBatchDto>()
                .name("carInspectionAlertReader")
                .dataSource(dataSource)
                .selectClause(
                        "SELECT c.id AS car_id, c.nickname AS car_nickname, m.member_uuid AS member_uuid, m.nick_name AS member_name, " +
                                "cil.inspection_date AS inspection_date, " +
                                "DATEDIFF(cil.inspection_date, CURDATE()) AS days_left, " +
                                "sm.fcm_token_id AS fcm_token_id"
                )
                .fromClause(
                        "FROM   car_inspection_log cil " +
                        "JOIN   car c ON cil.car_id = c.id " +
                        "JOIN   member m ON c.member_id = m.id " +
                        "LEFT JOIN social_member sm ON sm.member_id = m.id"
                )
                .whereClause(
                        "WHERE " +
                                "    DATEDIFF(cil.inspection_date, SYSDATE()) IN (60, 30, 15, 7, 3, 1, 0) " +
                                "    AND cil.inspection_status = 'PENDING' " +
                                "    AND sm.fcm_token_id is not null"
                )
                .sortKeys(Map.of("cil.inspection_date", Order.ASCENDING))
                .rowMapper((ResultSet rs, int rowNum) -> {
                    CarInspectionAlertBatchDto dto = new CarInspectionAlertBatchDto();
                    dto.setCarId(rs.getLong("car_id")); //
                    dto.setCarNickname(rs.getString("car_nickname"));
                    dto.setMemberUuid(rs.getString("member_uuid"));
                    dto.setMemberName(rs.getString("member_name"));
                    dto.setInspectionDate(rs.getDate("inspection_date").toLocalDate());
                    dto.setDaysLeft(rs.getInt("days_left"));
                    dto.setFcmTokenId(rs.getString("fcm_token_id")); // 추가
                    return dto;
                })
                .pageSize(10)
                .build();
    }

    // 알림 객체 생성 (실제 전송은 별도 서비스에서 처리)
    @Bean(name = "carInspectionAlertProcessor")
    public ItemProcessor<CarInspectionAlertBatchDto, NotificationBatchDto> carInspectionAlertProcessor() {
        return dto -> {
            log.info("[정기점검 알림 배치] 대상 데이터: {}", dto);
            NotificationBatchDto notiDto = new NotificationBatchDto();
            notiDto.setCarId(dto.getCarId());
            notiDto.setNotificationType(NotificationType.PUSH.name());
            notiDto.setNotificationDetailType(NotificationDetailType.INSPECTION_ALERT.name());
            notiDto.setMessage(
                    "차량 정기점검일이 임박했습니다. 점검일: " + dto.getInspectionDate() +
                            " (" +
                                     (dto.getDaysLeft() == 0 ? "오늘입니다!" : dto.getDaysLeft() + "일 남음") +
                            ")"
            );
            String fcmToken = dto.getFcmTokenId();
            sendPushAsync(fcmToken, notiDto.getMessage());
            return notiDto;
        };
    }

    @Async
    public void sendPushAsync(String fcmToken, String message) {
        pushService.sendPushNotification(
                FCMNotificationRequestDto.builder()
                        .fcmToken(fcmToken)
                        .title("차량 정기점검 알림")
                        .body(message)
                        .build()
        );
        throw new RuntimeException("비동기 테스트용 예외 발생"); // 비동기 테스트용 예외

    }

    // 알림 DB에 저장
    @Bean
    public JdbcBatchItemWriter<NotificationBatchDto> carInspectionAlertWriter() {
        return new JdbcBatchItemWriterBuilder<NotificationBatchDto>()
                .dataSource(dataSource)
                .sql("INSERT INTO notification (car_id, notification_type, notification_detail, message, created_at, updated_at) " +
                        "VALUES (:carId, :notificationType, :notificationDetailType, :message, SYSDATE(), SYSDATE())")
                .itemSqlParameterSourceProvider(new BeanPropertyItemSqlParameterSourceProvider<>())
                .build();
    }
}
