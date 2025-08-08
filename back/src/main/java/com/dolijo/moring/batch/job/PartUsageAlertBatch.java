package com.dolijo.moring.batch.job;

import com.dolijo.moring.batch.dto.PartUsageAlertBatchDto;
import com.dolijo.moring.batch.dto.FCMNotificationRequestDto;
import com.dolijo.moring.batch.dto.NotificationBatchDto;
import com.dolijo.moring.notifycation.service.PushService;
import com.dolijo.moring.notifycation.valueobject.NotificationDetailType;
import com.dolijo.moring.notifycation.valueobject.NotificationType;
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

@Configuration
@EnableAsync
@RequiredArgsConstructor
@Log4j2
public class PartUsageAlertBatch {
    private static final int PART_USAGE_ALERT_THRESHOLD = 80; // 부품 소모율 알림 임계값(%)
    private final JobRepository jobRepository;
    private final PlatformTransactionManager platformTransactionManager;
    private final DataSource dataSource;
    private final JobExecutionListener jobExecutionListener;
    private final PushService pushService;

    @Bean
    public Job partUsageAlertJob() {
        return new JobBuilder("partUsageAlertJob", jobRepository)
                .listener(jobExecutionListener)
                .start(partUsageAlertStep())
                .build();
    }

    @Bean
    public Step partUsageAlertStep() {
        return new StepBuilder("partUsageAlertStep", jobRepository)
                .<PartUsageAlertBatchDto, NotificationBatchDto>chunk(10, platformTransactionManager)
                .reader(partUsageAlertReader())
                .processor(partUsageAlertProcessor())
                .writer(partUsageAlertWriter())
                .build();
    }

    @Bean
    public JdbcPagingItemReader<PartUsageAlertBatchDto> partUsageAlertReader() {
        return new JdbcPagingItemReaderBuilder<PartUsageAlertBatchDto>()
                .name("partUsageAlertReader")
                .dataSource(dataSource)
                .selectClause(
                        "SELECT " +
                                "c.id AS car_id, " +
                                "c.nickname AS car_nickname, " +
                                "m.member_uuid AS member_uuid, " +
                               // "m.nick_name AS member_name, " +
                                "p.name_en AS part_name_en, " +
                                "pcl.created_at AS last_change, " +
                                "p.recommended_cycle_months AS cycle_months, " +
                                "sm.fcm_token_id AS fcm_token_id, " +
                                "ROUND((DATEDIFF(CURDATE(), pcl.created_at) / (p.recommended_cycle_months * 30)) * 100) AS percent_used "
                )
                .fromClause(
                        "FROM part p " +
                        "JOIN part_change_log pcl ON pcl.part_id = p.id " +
                        "JOIN car c ON pcl.car_id = c.id " +
                        "JOIN member m ON c.member_id = m.id " +
                        "LEFT JOIN social_member sm ON sm.member_id = m.id "
                )
                .whereClause(
                        "WHERE p.recommended_cycle_months > 0 " +
                        "AND pcl.created_at = (" +
                                                    " SELECT MAX(sub.created_at) " +
                                                    " FROM part_change_log sub" +
                                                    " WHERE sub.part_id = p.id AND sub.car_id = c.id" +
                                               ") " +
                        "AND sm.fcm_token_id is not null " + // FCM 토큰이 있는 경우에만 알림 전송
                        // 부품 소모가 임계값 이상 진행된 것만 알림 발생
                        "AND ROUND((DATEDIFF(CURDATE(), pcl.created_at) / (p.recommended_cycle_months * 30)) * 100) >= " + PART_USAGE_ALERT_THRESHOLD
                )
                .sortKeys(Map.of("car_id", Order.ASCENDING))
                .rowMapper((ResultSet rs, int rowNum) -> {
                    PartUsageAlertBatchDto dto = new PartUsageAlertBatchDto();
                    dto.setCarId(rs.getLong("car_id"));
                    dto.setCarNickname(rs.getString("car_nickname"));
                    dto.setMemberUuid(rs.getString("member_uuid"));
                    //dto.setMemberName(rs.getString("member_name"));
                    dto.setPartNameEn(rs.getString("part_name_en"));
                    dto.setLastChange(rs.getTimestamp("last_change").toLocalDateTime());
                    dto.setCycleMonths(rs.getInt("cycle_months"));
                    dto.setFcmTokenId(rs.getString("fcm_token_id"));
                    dto.setPercentUsed(rs.getInt("percent_used"));
                    return dto;
                })
                .pageSize(10)
                .build();
    }

    @Bean(name = "partUsageAlertProcessor")
    public ItemProcessor<PartUsageAlertBatchDto, NotificationBatchDto> partUsageAlertProcessor() {
        return dto -> {
            log.info("[부품 소모율 알림 배치] 대상 데이터: {}", dto);
            NotificationBatchDto notiDto = new NotificationBatchDto();
            notiDto.setCarId(dto.getCarId());
            notiDto.setNotificationType(NotificationType.PUSH.name());
            notiDto.setNotificationDetailType(NotificationDetailType.PART_ALERT.name());
            notiDto.setMessage(
                    "차량 부품 소모율이 " + PART_USAGE_ALERT_THRESHOLD + "%를 초과했습니다. 부품: " + dto.getPartNameEn() +
                            ", 소모율: " + dto.getPercentUsed() + "%"
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
                        .title("차량 부품 소모율 알림")
                        .body(message)
                        .build()
        );
    }

    @Bean
    public JdbcBatchItemWriter<NotificationBatchDto> partUsageAlertWriter() {
        return new JdbcBatchItemWriterBuilder<NotificationBatchDto>()
                .dataSource(dataSource)
                .sql("INSERT INTO notification (car_id, notification_type, notification_detail, message, created_at, updated_at) " +
                        "VALUES (:carId, :notificationType, :notificationDetailType, :message, SYSDATE(), SYSDATE())")
                .itemSqlParameterSourceProvider(new BeanPropertyItemSqlParameterSourceProvider<>())
                .build();
    }
}
