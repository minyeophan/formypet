package com.formypet.domain.auth.security;

import com.formypet.domain.auth.exception.RecoveryErrors;

import org.springframework.beans.factory.annotation.Qualifier;
import com.formypet.domain.auth.repository.jdbc.RecoveryLimitRepository;
import org.springframework.stereotype.Component;
import org.springframework.transaction.*;
import org.springframework.transaction.support.TransactionTemplate;
import java.time.*;

@Component
public class RecoveryRateLimiter {
    private final RecoveryLimitRepository limits;
    private final TransactionTemplate transactions;
    private final RecoveryCrypto crypto;
    private final Clock clock;
    public RecoveryRateLimiter(RecoveryLimitRepository limits,PlatformTransactionManager manager,RecoveryCrypto crypto,
                               @Qualifier("recoveryClock") Clock clock){
        this.limits=limits;this.crypto=crypto;this.clock=clock;
        transactions=new TransactionTemplate(manager);
        transactions.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
    }
    public void consume(String scope,String key,int maximum,int windowSeconds,int cooldownSeconds){
        boolean accepted=Boolean.TRUE.equals(transactions.execute(status->{
            Instant now=clock.instant();
            String bucket=crypto.digest("limit",scope+"\0"+key);
            limits.initialize(bucket,now,windowSeconds);
            var row=limits.lock(bucket);
            Instant start=row.windowStart();
            Instant last=row.lastRequestAt();
            int count=row.requestCount();
            if(!now.isBefore(start.plusSeconds(windowSeconds))){start=now;count=0;}
            if(count>=maximum||(cooldownSeconds>0&&now.isBefore(last.plusSeconds(cooldownSeconds))))return false;
            limits.recordAccepted(bucket,start,now,count+1);return true;
        }));
        if(!accepted)throw RecoveryErrors.error(429,"PASSWORD_RESET_RATE_LIMITED","잠시 후 다시 시도해 주세요.");
    }
}
