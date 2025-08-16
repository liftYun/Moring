package com.dolijo.moring.security.hmac;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.Map;

public interface HmacKeyService {
    String resolveSecret(String deviceId, String keyId);
}

@Component
@RequiredArgsConstructor
class PropsHmacKeyService implements HmacKeyService {
    private final DeviceHmacProps props;

    @Override
    public String resolveSecret(String deviceId, String keyId) {
        Map<String, String> keys = props.getClients() == null ? null : props.getClients().get(deviceId);
        if (keys == null) return null;
        String kid = (keyId == null || keyId.isBlank()) ? props.getDefaultKeyId() : keyId;
        return keys.get(kid);
    }
}
