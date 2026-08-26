package com.petyilgi;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

@EnableJpaAuditing
@SpringBootApplication
@EnableScheduling
public class PetyilgiApplication {

    public static void main(String[] args) {
        SpringApplication.run(PetyilgiApplication.class, args);
    }
}
