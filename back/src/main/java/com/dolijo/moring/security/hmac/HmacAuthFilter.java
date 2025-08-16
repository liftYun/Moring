package com.dolijo.moring.security.hmac;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.util.StreamUtils;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.util.ContentCachingRequestWrapper;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Duration;
import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.util.Base64;
import java.util.List;
import java.util.Set;

@RequiredArgsConstructor
public class HmacAuthFilter extends OncePerRequestFilter {

    private final HmacKeyService hmacKeyService;
    private final NonceStore nonceStore;
    private final Duration allowedSkew; // ex) props.skewSeconds

    private final List<String> protectedPatterns = List.of(
            "/api/v1/notifications/send/"
    );

    // 헤더 키
    private static final String HDR_DEVICE_ID = "X-Device-Id";
    private static final String HDR_TIMESTAMP = "X-Timestamp";
    private static final String HDR_NONCE     = "X-Nonce";
    private static final String HDR_SIGNATURE = "X-Signature";
    private static final String HDR_KEY_ID    = "X-Key-Id"; // optional

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String uri = request.getRequestURI();
        return protectedPatterns.stream().noneMatch(uri::startsWith);
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req,
                                    HttpServletResponse res,
                                    FilterChain chain) throws ServletException, IOException {

        // 바디 재사용을 위해 래핑
        ContentCachingRequestWrapper wrapped = new ContentCachingRequestWrapper(req);

        String deviceId  = req.getHeader(HDR_DEVICE_ID);
        String ts        = req.getHeader(HDR_TIMESTAMP);
        String nonce     = req.getHeader(HDR_NONCE);
        String signature = req.getHeader(HDR_SIGNATURE);
        String keyId     = req.getHeader(HDR_KEY_ID);

        if (isBlank(deviceId) || isBlank(ts) || isBlank(nonce) || isBlank(signature)) {
            res.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            res.setContentType("application/json");
            res.getWriter().write("{\"error\":\"missing_hmac_headers\"}");
            return;
        }

        String secret = hmacKeyService.resolveSecret(deviceId, keyId);
        if (isBlank(secret)) {
            unauthorized(res, "unknown_device_or_key");
            return;
        }

        if (!isTimestampValid(ts, allowedSkew)) {
            unauthorized(res, "invalid_timestamp");
            return;
        }

        if (!nonceStore.registerOnce(deviceId, nonce, allowedSkew)) {
            unauthorized(res, "nonce_replay");
            return;
        }

        // body hash
        byte[] bodyBytes = StreamUtils.copyToByteArray(wrapped.getInputStream());
        String bodyHash = sha256Base64(bodyBytes);

        // path + query
        String pathWithQuery = req.getRequestURI() + (req.getQueryString() == null ? "" : "?" + req.getQueryString());

        String signingString = req.getMethod() + "\n" + pathWithQuery + "\n" + bodyHash + "\n" + ts + "\n" + nonce;
        String expected = hmacSha256Base64(secret, signingString);

        if (!constantTimeEquals(signature, expected)) {
            unauthorized(res, "bad_signature");
            return;
        }

        // 인증 부여
        var auth = new UsernamePasswordAuthenticationToken(
                deviceId, null, Set.of(new SimpleGrantedAuthority("SCOPE_device:telemetry"))
        );
        org.springframework.security.core.context.SecurityContextHolder.getContext().setAuthentication(auth);

        // 바디를 래핑한 객체로 체인 진행
        chain.doFilter(wrapped, res);
    }

    private static boolean isBlank(String s){ return s==null || s.isBlank(); }

    private static boolean isTimestampValid(String ts, Duration skew) {
        try {
            Instant t = Instant.parse(ts); // e.g. 2025-08-16T03:10:00Z
            Instant now = Instant.now();
            return !t.isBefore(now.minus(skew)) && !t.isAfter(now.plus(skew));
        } catch (DateTimeParseException e) {
            return false;
        }
    }

    private static String sha256Base64(byte[] data) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            return Base64.getEncoder().encodeToString(md.digest(data));
        } catch (Exception e) { throw new IllegalStateException(e); }
    }

    private static String hmacSha256Base64(String secret, String message) {
        try {
            javax.crypto.Mac mac = javax.crypto.Mac.getInstance("HmacSHA256");
            mac.init(new javax.crypto.spec.SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            return Base64.getEncoder().encodeToString(mac.doFinal(message.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) { throw new IllegalStateException(e); }
    }

    private static boolean constantTimeEquals(String a, String b) {
        if (a == null || b == null) return false;
        if (a.length() != b.length()) return false;
        int r = 0;
        for (int i=0;i<a.length();i++) r |= a.charAt(i) ^ b.charAt(i);
        return r == 0;
    }

    private static void unauthorized(HttpServletResponse res, String code) throws IOException {
        res.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        res.setContentType("application/json");
        res.getWriter().write("{\"error\":\"" + code + "\"}");
    }
}
