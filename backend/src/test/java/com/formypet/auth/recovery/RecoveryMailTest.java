package com.formypet.auth.recovery;

import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mail.javamail.JavaMailSenderImpl;
import org.springframework.test.util.ReflectionTestUtils;
import jakarta.mail.internet.MimeMessage;
import java.time.Clock;
import java.util.concurrent.*;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class RecoveryMailTest {
    @Test void messageUsesAccountRecipientAndDoesNotSendPasswordOnCompletion() throws Exception {
        var properties=new RecoveryProperties();
        properties.getMail().setFrom("sender@example.com");
        var transport=new RecoveryMailTransport(properties);
        var sent=new LinkedBlockingQueue<MimeMessage>();
        var sender=new JavaMailSenderImpl(){
            @Override public void send(MimeMessage message){sent.add(message);}
        };
        ReflectionTestUtils.setField(transport,"sender",sender);
        transport.sendCode("stored@example.com","012345");
        var code=sent.remove();
        assertThat(code.getAllRecipients()[0].toString()).isEqualTo("stored@example.com");
        assertThat(code.getContent().toString()).contains("012345","10분");
        transport.sendChanged("stored@example.com");
        assertThat(sent.remove().getContent().toString()).contains("변경").doesNotContain("012345");
        assertThatThrownBy(()->transport.sendCode("user@example.com\r\nBcc:evil@example.com","123456"))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test void enabledConfigurationRequiresValidMailAndDistinctSecrets() {
        var properties=new RecoveryProperties();properties.setEnabled(true);
        assertThatThrownBy(properties::validate).isInstanceOf(IllegalStateException.class);
        properties.setHmacSecret("a".repeat(32));properties.setTokenSecret("b".repeat(32));
        properties.validate();
        assertThatThrownBy(()->new RecoveryMailTransport(properties).configure()).isInstanceOf(IllegalStateException.class);
        assertThat(properties.toString()).doesNotContain("a".repeat(32));
    }

    @Test void boundedQueueDropsOverflowAndContinuesAfterSmtpFailure() throws Exception {
        var properties=new RecoveryProperties();properties.setQueueCapacity(1);
        var transport=mock(RecoveryMailTransport.class);
        var entered=new CountDownLatch(1);var release=new CountDownLatch(1);var next=new CountDownLatch(1);
        doAnswer(call->{entered.countDown();release.await(5,TimeUnit.SECONDS);throw new RuntimeException("smtp");})
                .when(transport).sendChanged("first@example.com");
        doAnswer(call->{next.countDown();return null;}).when(transport).sendChanged("second@example.com");
        var queue=new RecoveryMailQueue(properties,transport,mock(JdbcTemplate.class),Clock.systemUTC());
        try{
            queue.changedAfterCommit("first","first@example.com");
            assertThat(entered.await(5,TimeUnit.SECONDS)).isTrue();
            queue.changedAfterCommit("second","second@example.com");
            assertThatCode(()->queue.changedAfterCommit("overflow","third@example.com")).doesNotThrowAnyException();
            release.countDown();
            assertThat(next.await(5,TimeUnit.SECONDS)).isTrue();
            verify(transport,never()).sendChanged("third@example.com");
        }finally{release.countDown();queue.close();}
    }

    @Test void invalidatedCodeIsNotHandedToSmtp() throws Exception {
        var properties=new RecoveryProperties();
        var transport=mock(RecoveryMailTransport.class);var jdbc=mock(JdbcTemplate.class);
        var checked=new CountDownLatch(1);
        when(jdbc.queryForObject(anyString(),eq(Integer.class),any(),any())).thenAnswer(call->{checked.countDown();return 0;});
        var queue=new RecoveryMailQueue(properties,transport,jdbc,Clock.systemUTC());
        try{
            queue.codeAfterCommit("old","stored@example.com","123456");
            assertThat(checked.await(5,TimeUnit.SECONDS)).isTrue();
            verifyNoInteractions(transport);
        }finally{queue.close();}
    }
}
