package com.formypet.auth;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.formypet.auth.recovery.RecoveryMailTransport;
import com.formypet.support.IntegrationTestSupport;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import java.util.*;
import java.util.concurrent.*;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@AutoConfigureMockMvc
@TestPropertySource(properties = {
    "app.password-reset.enabled=true",
    "app.password-reset.hmac-secret=test-recovery-hmac-secret-at-least-32-bytes",
    "app.password-reset.token-secret=test-recovery-token-secret-at-least-32-bytes",
    "app.password-reset.mail.username=sender@example.com",
    "app.password-reset.mail.password=only-test",
    "app.password-reset.mail.from=sender@example.com"
})
class RecoveryFlowIntegrationTest extends IntegrationTestSupport {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired JdbcTemplate jdbc;
    @Autowired AuthService auth;
    @Autowired org.springframework.transaction.support.TransactionTemplate transactions;
    @Autowired com.formypet.auth.repository.UserRepository users;
    @Autowired com.formypet.notification.DeviceTokenService devices;
    @Autowired com.formypet.auth.recovery.RecoveryCleanup cleanup;
    @Autowired com.formypet.auth.recovery.RecoveryCrypto recoveryCrypto;
    @Autowired com.formypet.auth.recovery.RecoveryMailQueue mailQueue;
    @org.springframework.beans.factory.annotation.Value("${app.jwt.secret}") String jwtSecret;
    @MockitoBean RecoveryMailTransport mail;
    @org.springframework.test.context.bean.override.mockito.MockitoSpyBean
    com.formypet.auth.recovery.RecoveryRateLimiter rateLimiter;
    final BlockingQueue<String> codes = new LinkedBlockingQueue<>();
    String email;

    @BeforeEach void setup() throws Exception {
        email = UUID.randomUUID()+"@example.com";
        jdbc.update("DELETE FROM password_reset_limits");
        codes.clear();
        doAnswer(call -> { codes.offer(call.getArgument(1)); return null; })
                .when(mail).sendCode(eq(email), anyString());
    }

    JsonNode postJson(String path, Map<String, ?> data, int status) throws Exception {
        var response = mvc.perform(post("/api/v1/auth/"+path).contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(data))).andExpect(status().is(status)).andReturn();
        return json.readTree(response.getResponse().getContentAsString());
    }
    JsonNode register() throws Exception {
        return postJson("register",Map.of("email",email,"password","Original123!","nickname","test"),201).path("data");
    }

    @Test void limitsNeverAcquireASecondConnectionInsideRecoveryTransaction() throws Exception {
        doAnswer(call -> {
            assertThat(org.springframework.transaction.support.TransactionSynchronizationManager.isActualTransactionActive()).isFalse();
            return call.callRealMethod();
        }).when(rateLimiter).consume(anyString(),anyString(),anyInt(),anyInt(),anyInt());
        register();
        var challenge=request();
        var verified=verify(challenge.path("challengeId").asText(),codes.poll(5,TimeUnit.SECONDS),"limit-check-verify");
        postJson("password-reset/confirm",Map.of("resetToken",verified.path("resetToken").asText(),
                "newPassword","Changed123!","requestId","limit-check-confirm"),200);
    }

    @Test void invalidLoginDoesNotDiscloseAccountExistence() throws Exception {
        register();
        var known=postJson("login",Map.of("email",email,"password","Wrong123!"),401);
        var unknown=postJson("login",Map.of("email",UUID.randomUUID()+"@example.com","password","Wrong123!"),401);
        assertThat(unknown.path("detail")).isEqualTo(known.path("detail"));
    }
    JsonNode request() throws Exception {
        return postJson("password-reset/request",Map.of("email",email),200).path("data");
    }
    JsonNode verify(String id,String code,String operation) throws Exception {
        return postJson("password-reset/verify",Map.of("challengeId",id,"code",code,"requestId",operation),200).path("data");
    }
    String code() throws Exception {
        String value=codes.poll(10,TimeUnit.SECONDS); assertThat(value).isNotNull(); return value;
    }

    @Test void resetRevokesSessionsAndRetriesDoNotChangePasswordAgain() throws Exception {
        var old=register();
        String id=request().path("challengeId").asText(), code=code(), op=UUID.randomUUID().toString();
        var verified=verify(id,code,op);
        assertThat(verify(id,code,op)).isEqualTo(verified);
        String token=verified.path("resetToken").asText(), confirm=UUID.randomUUID().toString();
        var body=Map.of("resetToken",token,"newPassword","Replacement123!","requestId",confirm);
        postJson("password-reset/confirm",body,200);
        postJson("password-reset/confirm",body,200);
        assertThat(jdbc.queryForObject("SELECT auth_version FROM users WHERE email=?",Long.class,email)).isEqualTo(1);
        postJson("password-reset/confirm",Map.of("resetToken",token,"newPassword","Different123!","requestId",confirm),409);
        postJson("login",Map.of("email",email,"password","Original123!"),401);
        postJson("login",Map.of("email",email,"password","Replacement123!"),200);
        postJson("refresh",Map.of("refreshToken",old.path("refreshToken").asText()),401);
        mvc.perform(get("/api/v1/pets").header("Authorization","Bearer "+old.path("accessToken").asText()))
                .andExpect(status().isUnauthorized());
    }

    @Test void wrongAttemptsPersistAndAccountLoginRemainsAvailable() throws Exception {
        register(); String id=request().path("challengeId").asText(), correct=code();
        String wrong=correct.equals("000000")?"111111":"000000";
        for(int i=0;i<5;i++) postJson("password-reset/verify",
                Map.of("challengeId",id,"code",wrong,"requestId",UUID.randomUUID().toString()),400);
        postJson("password-reset/verify",Map.of("challengeId",id,"code",correct,"requestId",UUID.randomUUID().toString()),400);
        assertThat(jdbc.queryForObject("SELECT attempts FROM password_reset_challenges WHERE id=?",Integer.class,id)).isEqualTo(5);
        postJson("login",Map.of("email",email,"password","Original123!"),200);
    }

    @Test void resendDoesNotRevokeVerifiedCapability() throws Exception {
        register(); String id=request().path("challengeId").asText();
        String token=verify(id,code(),UUID.randomUUID().toString()).path("resetToken").asText();
        jdbc.update("UPDATE password_reset_limits SET last_request_at=DATE_SUB(last_request_at,INTERVAL 61 SECOND)");
        request();
        postJson("password-reset/confirm",Map.of("resetToken",token,"newPassword","Replacement123!","requestId",UUID.randomUUID().toString()),200);
    }

    @Test void nonexistentAccountHasSameEnvelopeButCannotVerify() throws Exception {
        var requested=request(); assertThat(requested.path("challengeId").asText()).hasSize(43);
        assertThat(requested.has("expiresAt")).isTrue();
        postJson("password-reset/verify",Map.of("challengeId",requested.path("challengeId").asText(),
                "code","123456","requestId",UUID.randomUUID().toString()),400);
        verifyNoInteractions(mail);
    }

    @Test void refreshCannotResurrectTokenFromEarlierTransactionSnapshot() throws Exception {
        var old=register();
        String id=request().path("challengeId").asText();
        String token=verify(id,code(),UUID.randomUUID().toString()).path("resetToken").asText();
        var snapshotRead=new CountDownLatch(1);
        var resetDone=new CountDownLatch(1);
        try(var executor=Executors.newSingleThreadExecutor()){
            var result=executor.submit(()->transactions.execute(status->{
                jdbc.queryForList("SELECT * FROM refresh_tokens WHERE token=?",old.path("refreshToken").asText());
                snapshotRead.countDown();
                try{if(!resetDone.await(10,TimeUnit.SECONDS))throw new AssertionError("reset timed out");}
                catch(InterruptedException e){throw new RuntimeException(e);}
                try{auth.refresh(old.path("refreshToken").asText());return false;}
                catch(org.springframework.security.authentication.BadCredentialsException expected){status.setRollbackOnly();return true;}
            }));
            try {
                assertThat(snapshotRead.await(10,TimeUnit.SECONDS)).isTrue();
                postJson("password-reset/confirm",Map.of("resetToken",token,"newPassword","Replacement123!","requestId",UUID.randomUUID().toString()),200);
            }finally{resetDone.countDown();}
            assertThat(result.get(15,TimeUnit.SECONDS)).isTrue();
        }
    }

    @Test void resendInvalidatesOnlyPendingCodeAndEnforcesCooldown() throws Exception {
        register(); String first=request().path("challengeId").asText(), firstCode=code();
        postJson("password-reset/request",Map.of("email",email.toUpperCase(Locale.ROOT)),429);
        jdbc.update("UPDATE password_reset_limits SET last_request_at=DATE_SUB(last_request_at,INTERVAL 61 SECOND)");
        String second=request().path("challengeId").asText(),secondCode=code();
        postJson("password-reset/verify",Map.of("challengeId",first,"code",firstCode,"requestId",UUID.randomUUID().toString()),400);
        verify(second,secondCode,UUID.randomUUID().toString());
    }

    @Test void expiredCodeAndExpiredResetTokenAreRejected() throws Exception {
        register();String id=request().path("challengeId").asText(),code=code();
        jdbc.update("UPDATE password_reset_challenges SET expires_at=DATE_SUB(created_at,INTERVAL 1 SECOND) WHERE id=?",id);
        postJson("password-reset/verify",Map.of("challengeId",id,"code",code,"requestId",UUID.randomUUID().toString()),400);
        jdbc.update("UPDATE password_reset_limits SET last_request_at=DATE_SUB(last_request_at,INTERVAL 61 SECOND)");
        id=request().path("challengeId").asText();
        String token=verify(id,code(),UUID.randomUUID().toString()).path("resetToken").asText();
        jdbc.update("UPDATE password_reset_challenges SET reset_expires_at=DATE_SUB(created_at,INTERVAL 1 SECOND) WHERE id=?",id);
        postJson("password-reset/confirm",Map.of("resetToken",token,"newPassword","Replacement123!","requestId",UUID.randomUUID().toString()),400);
    }

    @Test void concurrentVerificationGrantsOnlyOneOperation() throws Exception {
        register();String id=request().path("challengeId").asText(),code=code();
        var gate=new CountDownLatch(1);
        try(var executor=Executors.newFixedThreadPool(2)){
            Callable<Integer> attempt=()->{
                gate.await();
                return mvc.perform(post("/api/v1/auth/password-reset/verify").contentType(MediaType.APPLICATION_JSON)
                    .content(json.writeValueAsString(Map.of("challengeId",id,"code",code,"requestId",UUID.randomUUID().toString()))))
                    .andReturn().getResponse().getStatus();
            };
            var one=executor.submit(attempt);var two=executor.submit(attempt);gate.countDown();
            assertThat(List.of(one.get(15,TimeUnit.SECONDS),two.get(15,TimeUnit.SECONDS))).containsExactlyInAnyOrder(200,400);
        }
    }

    @Test void profileWriteStartedBeforeResetCannotRestoreOldPasswordOrSessionVersion() throws Exception {
        register();String id=request().path("challengeId").asText();
        String token=verify(id,code(),UUID.randomUUID().toString()).path("resetToken").asText();
        var loaded=new CountDownLatch(1);var resetDone=new CountDownLatch(1);
        try(var executor=Executors.newSingleThreadExecutor()){
            var result=executor.submit(()->transactions.execute(status->{
                var user=users.findByEmail(email).orElseThrow();
                loaded.countDown();
                try{if(!resetDone.await(10,TimeUnit.SECONDS))throw new AssertionError("reset timed out");}
                catch(InterruptedException e){throw new RuntimeException(e);}
                user.updateNickname("Updated nickname");
                users.flush();return true;
            }));
            try{
                assertThat(loaded.await(10,TimeUnit.SECONDS)).isTrue();
                postJson("password-reset/confirm",Map.of("resetToken",token,"newPassword","Replacement123!","requestId",UUID.randomUUID().toString()),200);
            }finally{resetDone.countDown();}
            assertThat(result.get(15,TimeUnit.SECONDS)).isTrue();
        }
        assertThat(jdbc.queryForObject("SELECT auth_version FROM users WHERE email=?",Long.class,email)).isEqualTo(1);
        postJson("login",Map.of("email",email,"password","Original123!"),401);
        postJson("login",Map.of("email",email,"password","Replacement123!"),200);
    }

    @Test void legacyJwtAndOtherAccountSessionsAreHandledCorrectly() throws Exception {
        register();
        String legacy=io.jsonwebtoken.Jwts.builder().subject(email)
            .expiration(new java.util.Date(System.currentTimeMillis()+60000))
            .signWith(io.jsonwebtoken.security.Keys.hmacShaKeyFor(jwtSecret.getBytes(java.nio.charset.StandardCharsets.UTF_8)))
            .compact();
        mvc.perform(get("/api/v1/pets").header("Authorization","Bearer "+legacy)).andExpect(status().isOk());
        var other=postJson("register",Map.of("email",UUID.randomUUID()+"@example.com","password","Original123!","nickname","other"),201).path("data");
        String id=request().path("challengeId").asText();
        String token=verify(id,code(),UUID.randomUUID().toString()).path("resetToken").asText();
        postJson("password-reset/confirm",Map.of("resetToken",token,"newPassword","Replacement123!","requestId",UUID.randomUUID().toString()),200);
        mvc.perform(get("/api/v1/pets").header("Authorization","Bearer "+legacy)).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/pets").header("Authorization","Bearer "+other.path("accessToken").asText())).andExpect(status().isOk());
    }

    @Test void staleAuthenticatedDeviceRegistrationCannotReenablePushAfterReset() throws Exception {
        register();
        long uid=jdbc.queryForObject("SELECT id FROM users WHERE email=?",Long.class,email);
        jdbc.update("INSERT INTO device_tokens(user_id,token,platform,enabled) VALUES(?,?,'ANDROID',TRUE)",uid,"recovery-device-"+uid);
        String id=request().path("challengeId").asText();
        String token=verify(id,code(),UUID.randomUUID().toString()).path("resetToken").asText();
        postJson("password-reset/confirm",Map.of("resetToken",token,"newPassword","Replacement123!","requestId",UUID.randomUUID().toString()),200);
        var stale=new org.springframework.security.authentication.UsernamePasswordAuthenticationToken(email,null,List.of());
        stale.setDetails(0L);
        var context=org.springframework.security.core.context.SecurityContextHolder.createEmptyContext();context.setAuthentication(stale);
        org.springframework.security.core.context.SecurityContextHolder.setContext(context);
        try{
            org.assertj.core.api.Assertions.assertThatThrownBy(()->devices.register(email,
                new com.formypet.notification.dto.DeviceTokenRequest("recovery-device-"+uid,"ANDROID")))
                .isInstanceOf(org.springframework.security.authentication.BadCredentialsException.class);
        }finally{org.springframework.security.core.context.SecurityContextHolder.clearContext();}
        assertThat(jdbc.queryForObject("SELECT enabled FROM device_tokens WHERE token=?",Boolean.class,"recovery-device-"+uid)).isFalse();
    }

    @Test void oauthAccountCannotObtainLocalPasswordAndMailFailureDoesNotLeakAccount() throws Exception {
        register();
        jdbc.update("UPDATE users SET registration_source='KAKAO' WHERE email=?",email);
        var requested=request();
        postJson("password-reset/verify",Map.of("challengeId",requested.path("challengeId").asText(),
                "code","123456","requestId",UUID.randomUUID().toString()),400);
        assertThat(jdbc.queryForObject("SELECT user_id FROM password_reset_challenges WHERE id=?",Long.class,requested.path("challengeId").asText())).isNull();
        org.mockito.Mockito.verify(mail,never()).sendCode(eq(email),anyString());
    }

    @Test void completionIsSingleUseUnderConcurrentRequests() throws Exception {
        register();String id=request().path("challengeId").asText();
        String token=verify(id,code(),UUID.randomUUID().toString()).path("resetToken").asText();
        var gate=new CountDownLatch(1);
        try(var executor=Executors.newFixedThreadPool(2)){
            Callable<Integer> attempt=()->{
                gate.await();
                return mvc.perform(post("/api/v1/auth/password-reset/confirm").contentType(MediaType.APPLICATION_JSON)
                    .content(json.writeValueAsString(Map.of("resetToken",token,"newPassword","Replacement123!","requestId",UUID.randomUUID().toString()))))
                    .andReturn().getResponse().getStatus();
            };
            var one=executor.submit(attempt);var two=executor.submit(attempt);gate.countDown();
            assertThat(List.of(one.get(15,TimeUnit.SECONDS),two.get(15,TimeUnit.SECONDS))).containsExactlyInAnyOrder(200,409);
        }
        assertThat(jdbc.queryForObject("SELECT auth_version FROM users WHERE email=?",Long.class,email)).isEqualTo(1);
    }

    @Test void hourlyLimitAndCleanupRetainOnlyNecessaryState() throws Exception {
        for(int i=0;i<5;i++){
            request();
            jdbc.update("UPDATE password_reset_limits SET last_request_at=DATE_SUB(last_request_at,INTERVAL 61 SECOND)");
        }
        postJson("password-reset/request",Map.of("email",email),429);
        jdbc.update("UPDATE password_reset_challenges SET expires_at=DATE_SUB(created_at,INTERVAL 1 SECOND) WHERE user_id IS NULL");
        cleanup.cleanup();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM password_reset_challenges WHERE user_id IS NULL",Integer.class)).isZero();
    }

    @Test void fakeChallengeCannotVerifyEvenWithMatchingCode() throws Exception {
        String id=request().path("challengeId").asText();
        jdbc.update("UPDATE password_reset_challenges SET code_hash=? WHERE id=?",
                recoveryCrypto.digest("code",id+"\0"+"123456"),id);
        for(int i=0;i<5;i++) postJson("password-reset/verify",Map.of("challengeId",id,
                "code","123456","requestId",UUID.randomUUID().toString()),400);
        assertThat(jdbc.queryForObject("SELECT attempts FROM password_reset_challenges WHERE id=?",Integer.class,id)).isEqualTo(5);
    }

    @Test void cleanupPreservesLiveTokenAndCompletionRetryWindow() throws Exception {
        register();String id=request().path("challengeId").asText();
        String token=verify(id,code(),UUID.randomUUID().toString()).path("resetToken").asText();
        jdbc.update("UPDATE password_reset_challenges SET expires_at=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 MINUTE) WHERE id=?",id);
        cleanup.cleanup();
        String operation=UUID.randomUUID().toString();
        var body=Map.of("resetToken",token,"newPassword","Replacement123!","requestId",operation);
        postJson("password-reset/confirm",body,200);
        jdbc.update("UPDATE password_reset_challenges SET reset_expires_at=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 MINUTE),completed_at=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 9 MINUTE) WHERE id=?",id);
        cleanup.cleanup();
        postJson("password-reset/confirm",body,200);
        jdbc.update("UPDATE password_reset_challenges SET completed_at=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 11 MINUTE) WHERE id=?",id);
        cleanup.cleanup();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM password_reset_challenges WHERE id=?",Integer.class,id)).isZero();
    }

    @Test void mailIsSubmittedOnlyAfterCommitNeverAfterRollback() throws Exception {
        transactions.executeWithoutResult(status->{
            mailQueue.changedAfterCommit("rolled-back",email);
            verifyNoInteractions(mail);
            status.setRollbackOnly();
        });
        transactions.executeWithoutResult(status->{
            mailQueue.changedAfterCommit("committed",email);
            verifyNoInteractions(mail);
        });
        org.mockito.Mockito.verify(mail,timeout(5000).times(1)).sendChanged(email);
    }
}
