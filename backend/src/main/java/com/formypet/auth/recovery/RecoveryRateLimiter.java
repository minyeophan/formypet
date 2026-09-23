package com.formypet.auth.recovery;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.*;
import org.springframework.transaction.support.TransactionTemplate;
import java.time.*;

@Component
public class RecoveryRateLimiter {
    private final JdbcTemplate jdbc;
    private final TransactionTemplate transactions;
    private final RecoveryCrypto crypto;
    private final Clock clock;
    public RecoveryRateLimiter(JdbcTemplate jdbc,PlatformTransactionManager manager,RecoveryCrypto crypto,
                               @Qualifier("recoveryClock") Clock clock){
        this.jdbc=jdbc;this.crypto=crypto;this.clock=clock;
        transactions=new TransactionTemplate(manager);
        transactions.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
    }
    public void consume(String scope,String key,int maximum,int windowSeconds,int cooldownSeconds){
        boolean accepted=Boolean.TRUE.equals(transactions.execute(status->{
            LocalDateTime now=LocalDateTime.ofInstant(clock.instant(),ZoneOffset.UTC);
            String bucket=crypto.digest("limit",scope+"\0"+key);
            jdbc.update("INSERT IGNORE INTO password_reset_limits(bucket_key,window_start,last_request_at,request_count) VALUES(?,?,?,0)",
                    bucket,now,now.minusSeconds(windowSeconds+1));
            var row=jdbc.queryForMap("SELECT * FROM password_reset_limits WHERE bucket_key=? FOR UPDATE",bucket);
            LocalDateTime start=date(row.get("window_start"));
            LocalDateTime last=date(row.get("last_request_at"));
            int count=((Number)row.get("request_count")).intValue();
            if(!now.isBefore(start.plusSeconds(windowSeconds))){start=now;count=0;}
            if(count>=maximum||now.isBefore(last.plusSeconds(cooldownSeconds)))return false;
            jdbc.update("UPDATE password_reset_limits SET window_start=?,last_request_at=?,request_count=? WHERE bucket_key=?",
                    start,now,count+1,bucket);return true;
        }));
        if(!accepted)throw RecoveryService.error(429,"PASSWORD_RESET_RATE_LIMITED","잠시 후 다시 시도해 주세요.");
    }
    private static LocalDateTime date(Object value){
        return value instanceof java.sql.Timestamp t?t.toLocalDateTime():(LocalDateTime)value;
    }
}
