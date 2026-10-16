package com.formypet.domain.auth.service.impl;

import com.formypet.domain.auth.security.RecoveryCrypto;
import com.formypet.domain.auth.client.RecoveryMailQueue;
import com.formypet.domain.auth.config.RecoveryProperties;
import com.formypet.domain.auth.service.RecoveryTransactions;
import com.formypet.domain.auth.dto.request.ResetVerifyRequest;
import com.formypet.domain.auth.dto.request.ResetConfirmRequest;
import com.formypet.domain.auth.dto.response.ResetChallengeResponse;
import com.formypet.domain.auth.dto.response.ResetVerifiedResponse;
import com.formypet.domain.auth.exception.RecoveryErrors;

import com.formypet.domain.auth.security.SessionGuard;
import com.formypet.global.exception.ApiException;
import org.springframework.beans.factory.annotation.Qualifier;
import com.formypet.domain.auth.entity.PasswordResetChallenge;
import com.formypet.domain.auth.repository.PasswordResetChallengeRepository;
import com.formypet.domain.auth.repository.jdbc.RecoveryCommands;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.*;

@Service
public class RecoveryTransactionsImpl implements RecoveryTransactions {
    private final PasswordResetChallengeRepository challenges;
    private final RecoveryCommands commands;
    private final SessionGuard sessions;
    private final RecoveryProperties properties;
    private final RecoveryCrypto crypto;
    private final RecoveryMailQueue mail;
    private final PasswordEncoder passwords;
    private final Clock clock;
    public RecoveryTransactionsImpl(PasswordResetChallengeRepository challenges,RecoveryCommands commands,SessionGuard sessions,RecoveryProperties properties,RecoveryCrypto crypto,
                           RecoveryMailQueue mail,PasswordEncoder passwords,
                           @Qualifier("recoveryClock") Clock clock){
        this.challenges=challenges;this.commands=commands;this.sessions=sessions;this.properties=properties;this.crypto=crypto;
        this.mail=mail;this.passwords=passwords;this.clock=clock;
    }
    @Transactional
    public ResetChallengeResponse request(String subject,Long identifiedUser){
        enabled();
        var user=identifiedUser==null?null:sessions.lock(identifiedUser);
        Long userId=user==null?null:user.id();
        String recipient=user!=null&&user.source().equals("LOCAL")?user.email():null;
        // OAuth and unknown accounts receive indistinguishable, non-verifiable challenges.
        if(recipient==null)userId=null;
        String id=crypto.id(),code=crypto.code();
        Instant now=clock.instant().truncatedTo(java.time.temporal.ChronoUnit.MICROS);
        commands.invalidatePending(subject);
        challenges.save(PasswordResetChallenge.pending(id,subject,userId,crypto.digest("code",id+"\0"+code),now));
        mail.codeAfterCommit(id,recipient,code);
        return new ResetChallengeResponse(id,now.plusSeconds(600),now.plusSeconds(60));
    }
    @Transactional(noRollbackFor=ApiException.class)
    public ResetVerifiedResponse verify(ResetVerifyRequest body){
        enabled();
        var row=lockChallenge(body.challengeId(),false);
        Instant now=clock.instant().truncatedTo(java.time.temporal.ChronoUnit.MICROS);
        String state=row.getState();
        String supplied=crypto.digest("code",body.challengeId()+"\0"+body.code());
        boolean matches=RecoveryCrypto.same(row.getCodeHash(),supplied);
        if(state.equals("VERIFIED")){
            if(!matches||!row.allowsVerificationRetry(body.requestId(),now))throw invalid();
            String token=crypto.token(body.challengeId(),body.requestId());
            if(!RecoveryCrypto.same(RecoveryCrypto.hash(token),row.getResetHash()))throw invalid();
            return new ResetVerifiedResponse(token,row.resetExpiresAt());
        }
        if(!row.acceptsVerificationAttempt(now))throw invalid();
        if(!matches||row.getUserId()==null){
            row.recordFailedAttempt();
            throw invalid();
        }
        String token=crypto.token(body.challengeId(),body.requestId());
        Instant expires=now.plusSeconds(300);
        row.markVerified(body.requestId(),RecoveryCrypto.hash(token),now);
        return new ResetVerifiedResponse(token,expires);
    }
    @Transactional
    public void confirm(ResetConfirmRequest body){
        enabled();
        var row=lockChallenge(RecoveryCrypto.hash(body.resetToken()),true);
        Instant now=clock.instant().truncatedTo(java.time.temporal.ChronoUnit.MICROS);
        String id=row.getId();
        String fingerprint=crypto.digest("confirm",body.newPassword());
        if("COMPLETED".equals(row.getState())){
            if(!row.allowsCompletionRetry(body.requestId(),now)
                    ||!RecoveryCrypto.same(fingerprint,row.getConfirmHash()))
                throw RecoveryErrors.error(409,"PASSWORD_RESET_REQUEST_CONFLICT","이미 사용되었거나 변경된 요청입니다.");
            return;
        }
        if(!row.canConfirm(now))throw invalid();
        long uid=row.getUserId();
        // lockChallenge has already locked and revalidated this user.
        var user=sessions.lock(uid);
        if(!user.source().equals("LOCAL"))throw invalid();
        commands.changePasswordAndRevokeSessions(uid,passwords.encode(body.newPassword()),now);
        challenges.refreshCurrent(row);
        row.markCompleted(body.requestId(),fingerprint,now);
        mail.changedAfterCommit(id,user.email());
    }
    private PasswordResetChallenge lockChallenge(String value,boolean resetHash){
        var owner=(resetHash?challenges.findOwnerByResetHash(value):challenges.findOwnerById(value)).orElseThrow(RecoveryTransactionsImpl::invalid);
        if(owner.userId()!=null)sessions.lock(owner.userId());
        return (resetHash?challenges.findCurrentByResetHash(value):challenges.findCurrentById(value)).orElseThrow(RecoveryTransactionsImpl::invalid);
    }
    private void enabled(){
        if(!properties.isEnabled())throw RecoveryErrors.error(503,"PASSWORD_RESET_UNAVAILABLE","현재 비밀번호 복구를 이용할 수 없습니다.");
    }
    private static ApiException invalid(){return RecoveryErrors.error(400,"PASSWORD_RESET_INVALID","인증 정보가 올바르지 않거나 만료되었습니다. 다시 요청해 주세요.");}

}
