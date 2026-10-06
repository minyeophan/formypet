package com.formypet.config;

import org.springframework.boot.web.embedded.tomcat.TomcatServletWebServerFactory;
import org.springframework.boot.web.server.WebServerFactoryCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class MultipartLimitsConfiguration {
    @Bean
    WebServerFactoryCustomizer<TomcatServletWebServerFactory> multipartConnectorLimits() {
        return factory -> factory.addConnectorCustomizers(connector -> {
            connector.setMaxPartCount(10);
            connector.setMaxPartHeaderSize(2 * 1024);
        });
    }
}
