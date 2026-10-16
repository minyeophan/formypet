package com.formypet.domain.user.service;

import com.formypet.domain.user.dto.request.PublicAccountDeletionRequest;
import com.formypet.domain.user.dto.response.PublicAccountDeletionReceipt;

public interface PublicAccountDeletionRequestService {
    PublicAccountDeletionReceipt submit(PublicAccountDeletionRequest request, String clientAddress);
}
