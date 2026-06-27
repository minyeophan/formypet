package com.petyilgi.support;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.sql.DriverManager;

import static org.junit.jupiter.api.Assertions.assertEquals;

@Testcontainers
class FlywayMigrationTest {

    @Container
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.0")
            .withDatabaseName("flyway_test")
            .withUsername("test")
            .withPassword("test");

    @Test
    void migratesEmptyDatabaseFromV1ThroughLatest() throws Exception {
        Flyway flyway = Flyway.configure()
                .dataSource(MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword())
                .load();

        flyway.migrate();

        assertEquals("19", flyway.info().current().getVersion().getVersion());
        try (var connection = DriverManager.getConnection(MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword());
             var statement = connection.prepareStatement("""
                     SELECT COUNT(*) FROM information_schema.columns
                     WHERE table_schema = DATABASE()
                       AND table_name = 'post_comments'
                       AND column_name = 'parent_comment_id'
                     """)) {
            try (var result = statement.executeQuery()) {
                result.next();
                assertEquals(1, result.getInt(1));
            }
        }
    }
}
