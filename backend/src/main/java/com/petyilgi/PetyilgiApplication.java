package com.petyilgi;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

@EnableJpaAuditing
@SpringBootApplication
public class PetyilgiApplication {

    public static void main(String[] args) {
        SpringApplication.run(PetyilgiApplication.class, args);
    }
}
