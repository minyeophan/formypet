package com.formypet.auth.recovery;

import jakarta.annotation.PostConstruct;
import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;
import java.nio.charset.StandardCharsets;

@Data
@Component
@ConfigurationProperties(prefix="app.password-reset")
public class RecoveryProperties {
    private boolean enabled=false;
    private String hmacSecret="";
    private String tokenSecret="";
    private int emailHourlyLimit=5;
    private int ipHourlyLimit=30;
    private int actionMinuteLimit=30;
    private int queueCapacity=100;
    private Mail mail=new Mail();
    @Data public static class Mail {
        private String host="smtp.gmail.com";
        private int port=587;
        private String username="";
        private String password="";
        private String from="";
        @Override public String toString(){return "RecoveryMail[redacted]";}
    }
    @PostConstruct void validate(){
        if(emailHourlyLimit<1 || ipHourlyLimit<1 || actionMinuteLimit<1 || queueCapacity<1)
            throw new IllegalStateException("Invalid password recovery limits");
        if(enabled && (hmacSecret.getBytes(StandardCharsets.UTF_8).length<32
                || tokenSecret.getBytes(StandardCharsets.UTF_8).length<32 || hmacSecret.equals(tokenSecret)))
            throw new IllegalStateException("Password recovery requires distinct secrets of at least 32 bytes");
    }
    @Override public String toString(){return "RecoveryProperties[redacted]";}
}
