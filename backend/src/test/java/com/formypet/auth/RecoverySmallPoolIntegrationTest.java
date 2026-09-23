package com.formypet.auth;

import com.formypet.auth.recovery.RecoveryMailTransport;
import com.formypet.auth.recovery.RecoveryService;
import com.formypet.support.IntegrationTestSupport;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import java.util.UUID;
import java.util.concurrent.*;
import static org.assertj.core.api.Assertions.assertThat;

@TestPropertySource(properties = {
    "spring.datasource.hikari.maximum-pool-size=1",
    "spring.datasource.hikari.minimum-idle=1",
    "spring.datasource.hikari.connection-timeout=1000",
    "app.password-reset.enabled=true",
    "app.password-reset.hmac-secret=test-recovery-hmac-secret-at-least-32-bytes",
    "app.password-reset.token-secret=test-recovery-token-secret-at-least-32-bytes",
    "app.password-reset.mail.username=sender@example.com",
    "app.password-reset.mail.password=only-test",
    "app.password-reset.mail.from=sender@example.com"
})
class RecoverySmallPoolIntegrationTest extends IntegrationTestSupport {
    @Autowired RecoveryService recovery;
    @MockitoBean RecoveryMailTransport mail;

    @Test void concurrentRequestsProgressWithOnlyOneDatabaseConnection() throws Exception {
        var gate=new CountDownLatch(1);
        try(var executor=Executors.newFixedThreadPool(3)) {
            Callable<String> request=()->{
                gate.await();
                return recovery.request(UUID.randomUUID()+"@example.com",UUID.randomUUID().toString()).challengeId();
            };
            var one=executor.submit(request);
            var two=executor.submit(request);
            var three=executor.submit(request);
            gate.countDown();
            assertThat(one.get(10,TimeUnit.SECONDS)).hasSize(43);
            assertThat(two.get(10,TimeUnit.SECONDS)).hasSize(43);
            assertThat(three.get(10,TimeUnit.SECONDS)).hasSize(43);
        }
    }
}
