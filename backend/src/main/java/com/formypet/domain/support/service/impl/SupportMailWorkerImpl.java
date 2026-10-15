package com.formypet.domain.support.service.impl;

import com.formypet.domain.support.service.SupportMailWorker;
import com.formypet.domain.support.client.SupportMailTransport;

import com.formypet.domain.support.entity.MailRetryPolicy;
import com.formypet.domain.support.entity.SupportMailMessage;
import com.formypet.domain.support.repository.SupportTicketRepository;
import com.formypet.domain.support.repository.jdbc.SupportOutboxCommands;
import java.time.Instant;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

@Service
@RequiredArgsConstructor
@Slf4j
public class SupportMailWorkerImpl implements SupportMailWorker {
    private final SupportOutboxCommands commands;
    private final SupportTicketRepository tickets;
    private final TransactionTemplate transactions;
    private final SupportMailTransport transport;

    public boolean processOne() {
        var claim = transactions.execute(status -> commands.claim(Instant.now()));
        if (claim == null) return false;
        try {
            var ticket = tickets.findById(claim.ticketId())
                    .orElseThrow(() -> new EmptyResultDataAccessException(1));
            var message = SupportMailMessage.from(ticket);
            transport.send(message.subject(), message.body(), message.replyTo());
            commands.sent(claim, Instant.now());
        } catch (Exception failure) {
            boolean exhausted = MailRetryPolicy.exhausted(claim.attempt());
            String status = exhausted ? "FAILED" : "PENDING";
            commands.failed(claim, status, MailRetryPolicy.nextAttempt(Instant.now(), claim.attempt()),
                    failure.getClass().getSimpleName());
            // SMTP exception messages can contain addresses and authentication diagnostics.
            log.warn("Support mail ticket={} attempt={} status={}", claim.ticketId(), claim.attempt(), status);
        }
        return true;
    }
}
