package com.formypet.notification;

import com.formypet.auth.repository.UserRepository;
import com.formypet.notification.dto.DeviceTokenRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class DeviceTokenService {
    private final JdbcTemplate jdbc;
    private final UserRepository users;

    @Transactional
    public void register(String email, DeviceTokenRequest request) {
        Long userId = users.findByEmail(email).orElseThrow().getId();
        String platform = request.platform().trim().toUpperCase();
        if (!platform.equals("ANDROID") && !platform.equals("IOS")) {
            throw new IllegalArgumentException("Platform must be ANDROID or IOS.");
        }
        jdbc.update("""
                INSERT INTO device_tokens (user_id, token, platform, enabled)
                VALUES (?, ?, ?, TRUE)
                ON DUPLICATE KEY UPDATE user_id = VALUES(user_id), platform = VALUES(platform), enabled = TRUE, updated_at = CURRENT_TIMESTAMP(6)
                """, userId, request.token().trim(), platform);
    }

    @Transactional
    public void disable(String email, String token) {
        Long userId = users.findByEmail(email).orElseThrow().getId();
        jdbc.update("UPDATE device_tokens SET enabled = FALSE, updated_at = CURRENT_TIMESTAMP(6) WHERE user_id = ? AND token = ?", userId, token);
    }
}
