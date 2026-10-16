package com.formypet.domain.notification.service.impl;

import com.formypet.domain.auth.security.SessionGuard;
import com.formypet.common.time.UtcTime;
import com.formypet.domain.notification.dto.request.NotificationSettingsRequest;
import com.formypet.domain.notification.dto.response.NotificationSettingsResponse;
import com.formypet.domain.notification.repository.jdbc.NotificationCommands;
import com.formypet.domain.notification.service.NotificationSettingsService;
import com.formypet.domain.policy.service.PolicyConsentService;
import java.time.Instant;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class NotificationSettingsServiceImpl implements NotificationSettingsService {
    private final NotificationCommands commands;
    private final SessionGuard sessions;
    private final PolicyConsentService policies;

    @Transactional(readOnly = true)
    public NotificationSettingsResponse getSettings(Long actorId) {
        return new NotificationSettingsResponse(commands.settings(actorId));
    }

    @Transactional
    public NotificationSettingsResponse updateSettings(Long actorId, NotificationSettingsRequest request) {
        var user = sessions.lockCurrent(actorId);
        if (Boolean.TRUE.equals(request.enabled())) policies.requireAccepted(user.id());
        commands.updateSettings(user.id(), request.enabled(), UtcTime.toDatabase(Instant.now()));
        return getSettings(actorId);
    }
}
