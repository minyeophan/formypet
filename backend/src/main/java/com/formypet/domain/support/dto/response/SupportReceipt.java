package com.formypet.domain.support.dto.response;

import java.time.Instant;

public record SupportReceipt(String id, Instant receivedAt) {}
