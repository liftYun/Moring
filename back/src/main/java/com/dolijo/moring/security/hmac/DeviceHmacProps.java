package com.dolijo.moring.security.hmac;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

import java.util.Map;

@Getter @Setter
@Component
@ConfigurationProperties(prefix = "device-hmac")
public class DeviceHmacProps {
    private long skewSeconds = 300;
    private String defaultKeyId = "v1";
    /** clients[deviceId][keyId] = secret */
    private Map<String, Map<String, String>> clients;
}
