package com.formypet.domain.support.repository;

import com.formypet.domain.support.entity.SupportTicket;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SupportTicketRepository extends JpaRepository<SupportTicket, Long> {
    Optional<SupportTicket> findByRequesterUserIdAndKindAndRequestId(long requester, String kind, String requestId);
    boolean existsByRequesterUserIdAndTargetPostId(long requester, long postId);
}
