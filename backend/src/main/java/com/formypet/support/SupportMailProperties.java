package com.formypet.support;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Data
@Component
@ConfigurationProperties(prefix = "app.support.mail")
public class SupportMailProperties {
    private boolean enabled;
    private String host = "smtp.gmail.com";
    private int port = 587;
    private String username = "";
    private String password = "";
    private String recipient = "";
    private String senderName = "포마펫 고객지원";

    @Override public String toString() { return "SupportMailProperties[credentials redacted]"; }
}
