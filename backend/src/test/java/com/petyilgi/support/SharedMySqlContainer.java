package com.petyilgi.support;

import org.testcontainers.containers.MySQLContainer;

final class SharedMySqlContainer {

    private static final MySQLContainer<?> MYSQL;

    static {
        MYSQL = new MySQLContainer<>("mysql:8.0")
                .withDatabaseName("petyilgi_test")
                .withUsername("test")
                .withPassword("test")
                .withInitScript("init-test.sql")
                .withCommand(
                        "--character-set-server=utf8mb4",
                        "--collation-server=utf8mb4_unicode_ci",
                        "--log-bin-trust-function-creators=1"
                );
        MYSQL.start();
    }

    private SharedMySqlContainer() {
    }

    static MySQLContainer<?> getInstance() {
        return MYSQL;
    }
}
