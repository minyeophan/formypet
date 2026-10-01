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
    private final com.formypet.auth.SessionGuard sessions;

    @Transactional
    public void register(Long actorId, DeviceTokenRequest request) {
        var user = sessions.lockCurrent(actorId);
        Long userId = user.id();
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
    public void disable(Long actorId, String token) {
        Long userId = sessions.lockCurrent(actorId).id();
        jdbc.update("UPDATE device_tokens SET enabled = FALSE, updated_at = CURRENT_TIMESTAMP(6) WHERE user_id = ? AND token = ?", userId, token);
    }
}
