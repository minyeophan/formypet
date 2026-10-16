package com.formypet.domain.support.service;

import com.formypet.domain.support.dto.request.InquiryRequest;
import com.formypet.domain.support.dto.request.ReportRequest;
import com.formypet.domain.support.dto.response.SupportReceipt;

public interface SupportService {
    SupportReceipt inquiry(Long actorId, InquiryRequest request);
    SupportReceipt report(Long actorId, long postId, ReportRequest request);
}
