package com.formypet.domain.auth.scheduling;
import org.springframework.beans.factory.annotation.Qualifier;
import com.formypet.domain.auth.repository.jdbc.RecoveryCommands;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import java.time.*;
@Component
public class RecoveryCleanup {
    private final RecoveryCommands commands;
    private final Clock clock;
    public RecoveryCleanup(RecoveryCommands commands,@Qualifier("recoveryClock") Clock clock){this.commands=commands;this.clock=clock;}
    @Scheduled(fixedDelayString="${app.password-reset.cleanup-interval-ms:3600000}")
    public void cleanup(){
        commands.cleanup(clock.instant());
    }
}
