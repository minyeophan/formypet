package com.formypet.domain.notification.repository.query;

import java.time.LocalDateTime;

public record DeviceTokenSnapshot(String token, LocalDateTime updatedAt) {}
