package com.formypet.domain.notification.service.impl;

import com.formypet.domain.auth.security.SessionGuard;
import com.formypet.domain.notification.dto.request.DeviceTokenRequest;
import com.formypet.domain.notification.repository.jdbc.NotificationCommands;
import com.formypet.domain.notification.service.DeviceTokenService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class DeviceTokenServiceImpl implements DeviceTokenService {
    private final NotificationCommands commands;
    private final SessionGuard sessions;

    @Transactional
    public void register(Long actorId, DeviceTokenRequest request) {
        var user = sessions.lockCurrent(actorId);
        String platform = request.platform().trim().toUpperCase();
        if (!platform.equals("ANDROID") && !platform.equals("IOS")) {
            throw new IllegalArgumentException("Platform must be ANDROID or IOS.");
        }
        commands.registerToken(user.id(), request.token().trim(), platform);
    }

    @Transactional
    public void disable(Long actorId, String token) {
        commands.disableToken(sessions.lockCurrent(actorId).id(), token);
    }
}
