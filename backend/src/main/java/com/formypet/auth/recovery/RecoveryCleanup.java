package com.formypet.auth.recovery;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import java.time.*;
@Component
public class RecoveryCleanup {
    private final JdbcTemplate jdbc;
    private final Clock clock;
    public RecoveryCleanup(JdbcTemplate jdbc,@Qualifier("recoveryClock") Clock clock){this.jdbc=jdbc;this.clock=clock;}
    @Scheduled(fixedDelayString="${app.password-reset.cleanup-interval-ms:3600000}")
    public void cleanup(){
        var now=LocalDateTime.ofInstant(clock.instant(),ZoneOffset.UTC);
        jdbc.update("""
            DELETE FROM password_reset_challenges
            WHERE expires_at<? AND (reset_expires_at IS NULL OR reset_expires_at<?)
              AND (completed_at IS NULL OR completed_at<?)
            """,now,now,now.minusMinutes(10));
        jdbc.update("DELETE FROM password_reset_limits WHERE last_request_at<?",now.minusHours(2));
    }
}
