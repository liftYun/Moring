package com.dolijo.moring.retry;

import com.dolijo.moring.batch.retry.FailedPush;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.log4j.Log4j2;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.redis.core.StringRedisTemplate;

import java.util.List;

@SpringBootTest
@Log4j2
class PushRetryQueueTest {

    @Autowired
    private StringRedisTemplate redisTemplate;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void printPushRetryQueueData() throws Exception {
        String key = "push-retry:queue";
        Long size = redisTemplate.opsForList().size(key);

        log.info("=== [push-retry:queue] size: {} ===", size);

        if (size == null || size == 0) {
            log.info("큐에 데이터가 없습니다.");
            return;
        }

        // 전체 데이터 읽기
        List<String> list = redisTemplate.opsForList().range(key, 0, -1);

        if (list != null) {
            for (int i = 0; i < list.size(); i++) {
                String json = list.get(i);
                log.info("Raw JSON #{}: {}", i, json);

                try {
                    FailedPush fp = objectMapper.readValue(json, FailedPush.class);
                    log.info("Parsed #{}: token={}, title={}, body={}, jobName={}, attempt={}, lastError={}",
                            i,
                            fp.getFcmToken(),
                            fp.getTitle(),
                            fp.getBody(),
                            fp.getJobName(),
                            fp.getAttempt(),
                            fp.getLastError());
                } catch (Exception e) {
                    log.error("JSON 파싱 실패: {}", json, e);
                }
            }
        }
    }
}