package com.formypet.auth.recovery;

import com.formypet.auth.SessionGuard;
import com.formypet.common.exception.ApiException;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.sql.Timestamp;
import java.time.*;
import java.util.*;
import static com.formypet.auth.recovery.RecoveryController.*;

@Service
public class RecoveryTransactions {
    private final JdbcTemplate jdbc;
    private final SessionGuard sessions;
    private final RecoveryProperties properties;
    private final RecoveryCrypto crypto;
    private final RecoveryMailQueue mail;
    private final PasswordEncoder passwords;
    private final Clock clock;
    public RecoveryTransactions(JdbcTemplate jdbc,SessionGuard sessions,RecoveryProperties properties,RecoveryCrypto crypto,
                           RecoveryMailQueue mail,PasswordEncoder passwords,
                           @Qualifier("recoveryClock") Clock clock){
        this.jdbc=jdbc;this.sessions=sessions;this.properties=properties;this.crypto=crypto;
        this.mail=mail;this.passwords=passwords;this.clock=clock;
    }
    @Transactional
    public Challenge request(String subject,Long identifiedUser){
        enabled();
        var user=identifiedUser==null?null:sessions.lock(identifiedUser);
        Long userId=user==null?null:user.id();
        String recipient=user!=null&&user.source().equals("LOCAL")?user.email():null;
        // OAuth and unknown accounts receive indistinguishable, non-verifiable challenges.
        if(recipient==null)userId=null;
        String id=crypto.id(),code=crypto.code();
        Instant now=clock.instant().truncatedTo(java.time.temporal.ChronoUnit.MICROS);
        jdbc.update("UPDATE password_reset_challenges SET state='INVALIDATED' WHERE subject_key=? AND state='PENDING'",subject);
        jdbc.update("""
            INSERT INTO password_reset_challenges(id,subject_key,user_id,code_hash,state,created_at,expires_at)
            VALUES(?,?,?,?,'PENDING',?,?)
            """,id,subject,userId,crypto.digest("code",id+"\0"+code),time(now),time(now.plusSeconds(600)));
        mail.codeAfterCommit(id,recipient,code);
        return new Challenge(id,now.plusSeconds(600),now.plusSeconds(60));
    }
    @Transactional(noRollbackFor=ApiException.class)
    public Verified verify(Verify body){
        enabled();
        var row=lockChallenge("id",body.challengeId());
        Instant now=clock.instant().truncatedTo(java.time.temporal.ChronoUnit.MICROS);
        String state=(String)row.get("state");
        String supplied=crypto.digest("code",body.challengeId()+"\0"+body.code());
        boolean matches=RecoveryCrypto.same((String)row.get("code_hash"),supplied);
        if(state.equals("VERIFIED")){
            if(!matches||!body.requestId().equals(row.get("verify_request_id"))
                    ||!now.isBefore(instant(row,"reset_expires_at")))throw invalid();
            String token=crypto.token(body.challengeId(),body.requestId());
            if(!RecoveryCrypto.same(RecoveryCrypto.hash(token),(String)row.get("reset_hash")))throw invalid();
            return new Verified(token,instant(row,"reset_expires_at"));
        }
        int attempts=((Number)row.get("attempts")).intValue();
        if(!state.equals("PENDING")||attempts>=5||!now.isBefore(instant(row,"expires_at")))throw invalid();
        if(!matches||row.get("user_id")==null){
            jdbc.update("UPDATE password_reset_challenges SET attempts=attempts+1 WHERE id=?",body.challengeId());
            throw invalid();
        }
        String token=crypto.token(body.challengeId(),body.requestId());
        Instant expires=now.plusSeconds(300);
        jdbc.update("""
            UPDATE password_reset_challenges SET state='VERIFIED',verify_request_id=?,reset_hash=?,reset_expires_at=? WHERE id=?
            """,body.requestId(),RecoveryCrypto.hash(token),time(expires),body.challengeId());
        return new Verified(token,expires);
    }
    @Transactional
    public void confirm(Confirm body){
        enabled();
        var row=lockChallenge("reset_hash",RecoveryCrypto.hash(body.resetToken()));
        Instant now=clock.instant().truncatedTo(java.time.temporal.ChronoUnit.MICROS);
        String id=(String)row.get("id");
        String fingerprint=crypto.digest("confirm",body.newPassword());
        if("COMPLETED".equals(row.get("state"))){
            if(!body.requestId().equals(row.get("confirm_request_id"))
                    ||!RecoveryCrypto.same(fingerprint,(String)row.get("confirm_hash"))
                    ||!now.isBefore(instant(row,"completed_at").plusSeconds(600)))
                throw error(409,"PASSWORD_RESET_REQUEST_CONFLICT","이미 사용되었거나 변경된 요청입니다.");
            return;
        }
        if(!"VERIFIED".equals(row.get("state"))||row.get("user_id")==null
                ||!now.isBefore(instant(row,"reset_expires_at")))throw invalid();
        long uid=((Number)row.get("user_id")).longValue();
        // lockChallenge has already locked and revalidated this user.
        var user=sessions.lock(uid);
        if(!user.source().equals("LOCAL"))throw invalid();
        jdbc.update("UPDATE users SET password_hash=?,auth_version=auth_version+1,updated_at=? WHERE id=?",
                passwords.encode(body.newPassword()),time(now),uid);
        jdbc.update("DELETE FROM refresh_tokens WHERE user_id=?",uid);
        jdbc.update("UPDATE device_tokens SET enabled=FALSE,updated_at=CURRENT_TIMESTAMP(6) WHERE user_id=?",uid);
        jdbc.update("UPDATE password_reset_challenges SET state='INVALIDATED' WHERE user_id=? AND state IN ('PENDING','VERIFIED')",uid);
        jdbc.update("""
            UPDATE password_reset_challenges SET state='COMPLETED',confirm_request_id=?,confirm_hash=?,completed_at=? WHERE id=?
            """,body.requestId(),fingerprint,time(now),id);
        mail.changedAfterCommit(id,user.email());
    }
    private Map<String,Object> lockChallenge(String column,String value){
        // column is exclusively one of the two internal constants at call sites.
        var rows=jdbc.queryForList("SELECT id,user_id FROM password_reset_challenges WHERE "+column+"=?",value);
        if(rows.isEmpty())throw invalid();
        Object uid=rows.getFirst().get("user_id");
        if(uid!=null)sessions.lock(((Number)uid).longValue());
        rows=jdbc.queryForList("SELECT * FROM password_reset_challenges WHERE "+column+"=? FOR UPDATE",value);
        if(rows.isEmpty())throw invalid();
        return rows.getFirst();
    }
    private void enabled(){
        if(!properties.isEnabled())throw error(503,"PASSWORD_RESET_UNAVAILABLE","현재 비밀번호 복구를 이용할 수 없습니다.");
    }
    private static Instant instant(Map<String,Object> row,String key){
        Object value=row.get(key);
        return (value instanceof Timestamp t?t.toLocalDateTime():(LocalDateTime)value).toInstant(ZoneOffset.UTC);
    }
    private static LocalDateTime time(Instant instant){return LocalDateTime.ofInstant(instant,ZoneOffset.UTC);}
    private static ApiException invalid(){return error(400,"PASSWORD_RESET_INVALID","인증 정보가 올바르지 않거나 만료되었습니다. 다시 요청해 주세요.");}
    static ApiException error(int status,String code,String detail){
        return new ApiException(HttpStatus.valueOf(status),"password-reset","Password recovery",detail,code);
    }
}
