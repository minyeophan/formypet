package com.formypet.domain.notification.service;

import com.formypet.domain.notification.dto.request.DeviceTokenRequest;

public interface DeviceTokenService {
    void register(Long actorId, DeviceTokenRequest request);
    void disable(Long actorId, String token);
}
