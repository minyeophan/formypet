package com.formypet.domain.auth.config;
import org.springframework.context.annotation.*;
import java.time.Clock;
@Configuration
public class RecoveryConfiguration {
    @Bean("recoveryClock") public Clock recoveryClock(){return Clock.systemUTC();}
}
