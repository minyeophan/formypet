package com.formypet;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

@EnableJpaAuditing
@SpringBootApplication
@EnableScheduling
public class FormypetApplication {

    public static void main(String[] args) {
        SpringApplication.run(FormypetApplication.class, args);
    }
}
