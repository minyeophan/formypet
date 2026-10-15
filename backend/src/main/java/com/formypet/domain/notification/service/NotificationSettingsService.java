package com.formypet.domain.notification.service;

import com.formypet.domain.notification.dto.request.NotificationSettingsRequest;
import com.formypet.domain.notification.dto.response.NotificationSettingsResponse;

public interface NotificationSettingsService {
    NotificationSettingsResponse getSettings(Long actorId);
    NotificationSettingsResponse updateSettings(Long actorId, NotificationSettingsRequest request);
}
