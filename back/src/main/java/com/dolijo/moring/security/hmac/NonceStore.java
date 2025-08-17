package com.dolijo.moring.security.hmac;

import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.concurrent.ConcurrentHashMap;

/** 실운영은 Redis(SETNX+EXPIRE) 권장. 여기선 인메모리 */
public interface NonceStore {
    boolean registerOnce(String deviceId, String nonce, Duration ttl);
}

@Component
class InMemoryNonceStore implements NonceStore {
    private static final class Entry { final long expMs; Entry(long e){this.expMs=e;} }
    private final ConcurrentHashMap<String, Entry> map = new ConcurrentHashMap<>();

    @Override
    public boolean registerOnce(String deviceId, String nonce, Duration ttl) {
        String key = deviceId + "::" + nonce;
        long exp = System.currentTimeMillis() + ttl.toMillis();
        Entry prev = map.putIfAbsent(key, new Entry(exp));
        if (prev != null) return false; // 재사용
        // 가끔 청소
        if (map.size() > 20000) {
            long now = System.currentTimeMillis();
            map.entrySet().removeIf(e -> e.getValue().expMs < now);
        }
        return true;
    }
}
