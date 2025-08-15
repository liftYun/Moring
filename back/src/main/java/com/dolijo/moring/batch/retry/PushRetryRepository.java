package com.dolijo.moring.batch.retry;// package com.dolijo.moring.notification.retry;

import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Repository;

@Log4j2
@Repository
@RequiredArgsConstructor
public class PushRetryRepository {

    private static final String RETRY_QUEUE_KEY = "push-retry:queue"; // 전역 큐
    private final StringRedisTemplate redis;
    private final ObjectMapper om;

    public void enqueue(FailedPush item) {
        try {
            String json = om.writeValueAsString(item);
            redis.opsForList().leftPush(RETRY_QUEUE_KEY, json);
        } catch (Exception e) {
            log.error("Failed to enqueue push retry: {}", item, e);
        }
    }

    /** 하나 꺼내기 (FIFO 느낌으로 rightPop) */
    public String popOne() {
        return redis.opsForList().rightPop(RETRY_QUEUE_KEY);
    }

    public Long size() {
        return redis.opsForList().size(RETRY_QUEUE_KEY);
    }
}