package com.petyilgi.support;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.sql.Connection;
import java.sql.DriverManager;

import static org.junit.jupiter.api.Assertions.assertEquals;

@Testcontainers
class FlywayMigrationTest {

    @Container
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.0")
            .withDatabaseName("flyway_test")
            .withUsername("test")
            .withPassword("test");

    @BeforeEach
    void cleanDatabase() {
        flyway(null).clean();
    }

    @Test
    void migratesEmptyDatabaseFromV1ThroughLatest() throws Exception {
        Flyway flyway = flyway(null);

        flyway.migrate();

        assertEquals("22", flyway.info().current().getVersion().getVersion());
        try (Connection connection = connection()) {
            assertEquals(1, count(connection, """
                    SELECT COUNT(*) FROM information_schema.columns
                    WHERE table_schema = DATABASE()
                      AND table_name = 'post_comments'
                      AND column_name = 'parent_comment_id'
                    """));
            assertEquals(1, count(connection, """
                    SELECT COUNT(*) FROM information_schema.tables
                    WHERE table_schema = DATABASE()
                      AND table_name = 'media_cleanup_queue'
                    """));
            assertCommentManagementSchema(connection);
            assertNotificationsSchema(connection);
        }
    }

    @Test
    void addsCommentManagementSchemaFromV20() throws Exception {
        Flyway flyway = flyway("20");
        flyway.migrate();

        flyway = flyway(null);
        flyway.migrate();

        assertEquals("22", flyway.info().current().getVersion().getVersion());
        try (Connection connection = connection()) {
            assertCommentManagementSchema(connection);
            assertNotificationsSchema(connection);
        }
    }

    @Test
    void removesOnlyLegacyActivityDataAndQueuesItsMedia() throws Exception {
        Flyway flyway = flyway("19");
        flyway.migrate();

        try (Connection connection = connection()) {
            insertRemovalFixtures(connection);
            assertRemovalFixtures(connection);
        }

        flyway = flyway(null);
        flyway.migrate();

        try (Connection connection = connection()) {
            assertRemovalResult(connection);
        }
    }

    @Test
    void completesWithoutDuplicateQueueEntriesAfterPartialRetry() throws Exception {
        Flyway flyway = flyway("19");
        flyway.migrate();

        try (Connection connection = connection()) {
            insertRemovalFixtures(connection);
            assertRemovalFixtures(connection);
            execute(connection, """
                    CREATE TABLE media_cleanup_queue (
                        storage_key VARCHAR(500) PRIMARY KEY,
                        created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
                    ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4
                    """);
            execute(connection, "INSERT INTO media_cleanup_queue (storage_key) VALUES ('records/play.jpg')");
        }

        flyway = flyway(null);
        flyway.migrate();

        try (Connection connection = connection()) {
            assertRemovalResult(connection);
            assertEquals(1, count(connection, """
                    SELECT COUNT(*) FROM media_cleanup_queue
                    WHERE storage_key = 'records/play.jpg'
                    """));
        }
    }

    private Flyway flyway(String target) {
        var configuration = Flyway.configure()
                .dataSource(MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword())
                .cleanDisabled(false);
        if (target != null) {
            configuration.target(target);
        }
        return configuration.load();
    }

    private Connection connection() throws Exception {
        return DriverManager.getConnection(MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword());
    }

    private void assertCommentManagementSchema(Connection connection) throws Exception {
        assertEquals(2, count(connection, """
                SELECT COUNT(*) FROM information_schema.columns
                WHERE table_schema = DATABASE()
                  AND table_name = 'post_comments'
                  AND column_name IN ('updated_at', 'deleted_at')
                """));
        assertEquals(1, count(connection, """
                SELECT COUNT(*) FROM information_schema.tables
                WHERE table_schema = DATABASE()
                  AND table_name = 'post_comment_reports'
                """));
        assertEquals(4, count(connection, """
                SELECT COUNT(*) FROM information_schema.statistics
                WHERE table_schema = DATABASE()
                  AND table_name = 'post_comments'
                  AND index_name = 'idx_post_comments_active_thread'
                """));
        assertEquals(0, count(connection, """
                SELECT COUNT(*) FROM information_schema.statistics
                WHERE table_schema = DATABASE()
                  AND table_name = 'post_comments'
                  AND index_name = 'idx_post_comments_thread_cursor'
                """));
        assertEquals(2, count(connection, """
                SELECT COUNT(*) FROM information_schema.statistics
                WHERE table_schema = DATABASE()
                  AND table_name = 'post_comment_reports'
                  AND index_name = 'uk_post_comment_reporter'
                """));
    }

    private void assertNotificationsSchema(Connection connection) throws Exception {
        assertEquals(1, count(connection, """
                SELECT COUNT(*) FROM information_schema.tables
                WHERE table_schema = DATABASE()
                  AND table_name = 'notifications'
                """));
        assertEquals(11, count(connection, """
                SELECT COUNT(*) FROM information_schema.columns
                WHERE table_schema = DATABASE()
                  AND table_name = 'notifications'
                  AND column_name IN (
                      'id', 'recipient_user_id', 'actor_user_id', 'actor_nickname',
                      'type', 'post_id', 'comment_id', 'title', 'body', 'read_at', 'created_at'
                  )
                """));
        assertEquals(2, count(connection, """
                SELECT COUNT(*) FROM information_schema.statistics
                WHERE table_schema = DATABASE()
                  AND table_name = 'notifications'
                  AND index_name = 'idx_notifications_recipient_cursor'
                """));
        assertEquals(2, count(connection, """
                SELECT COUNT(*) FROM information_schema.statistics
                WHERE table_schema = DATABASE()
                  AND table_name = 'notifications'
                  AND index_name = 'idx_notifications_recipient_created'
                """));
        assertEquals(2, count(connection, """
                SELECT COUNT(*) FROM information_schema.statistics
                WHERE table_schema = DATABASE()
                  AND table_name = 'notifications'
                  AND index_name = 'idx_notifications_unread'
                """));
    }

    private void insertRemovalFixtures(Connection connection) throws Exception {
        execute(connection, "INSERT INTO users (id, email, password_hash, nickname) VALUES (1, 'owner@example.com', 'hash', 'owner')");
        execute(connection, """
                INSERT INTO pets (id, user_id, name, species, birth_date, accent_color, bg_light)
                VALUES (1, 1, 'Mong', 'dog', '2020-01-01', '#000000', '#ffffff')
                """);
        execute(connection, """
                INSERT INTO activity_types (id, name, display_order)
                VALUES ('bath', 'bath', 20), ('groom', 'groom', 21)
                """);
        execute(connection, """
                INSERT INTO routines (id, pet_id, label, type_id, repeat_type, start_date)
                VALUES
                    (1, 1, 'play routine', 'play', 'daily', '2026-01-01'),
                    (2, 1, 'sleep routine', 'sleep', 'daily', '2026-01-01'),
                    (3, 1, 'checkup routine', 'checkup', 'daily', '2026-01-01'),
                    (4, 1, 'bath routine', 'bath', 'daily', '2026-01-01'),
                    (5, 1, 'groom routine', 'groom', 'daily', '2026-01-01')
                """);
        execute(connection, """
                INSERT INTO activity_records (id, pet_id, type_id, date, note, routine_id)
                VALUES
                    (1, 1, 'play', '2026-01-01', 'remove', 1),
                    (2, 1, 'sleep', '2026-01-01', 'remove', 2),
                    (3, 1, 'checkup', '2026-01-01', 'remove', 3),
                    (4, 1, 'meal', '2026-01-01', 'keep but unlink', 1),
                    (5, 1, 'vet', '2026-01-01', 'keep checkup reason', NULL),
                    (6, 1, 'bath', '2026-01-01', 'keep', 4),
                    (7, 1, 'walk', '2026-01-01', 'keep', NULL)
                """);
        execute(connection, "INSERT INTO record_meal (record_id, food_type) VALUES (4, 'dry')");
        execute(connection, """
                INSERT INTO record_walk (record_id)
                VALUES (1), (2), (7)
                """);
        execute(connection, """
                INSERT INTO record_vet (record_id, vet_visit_reason)
                VALUES (3, 'vaccination'), (5, 'checkup')
                """);
        execute(connection, """
                INSERT INTO routine_completions (id, routine_id, pet_id, activity_record_id, scheduled_date, status)
                VALUES
                    (1, 1, 1, 1, '2026-01-01', 'COMPLETED'),
                    (2, 2, 1, 2, '2026-01-01', 'COMPLETED'),
                    (3, 3, 1, 3, '2026-01-01', 'COMPLETED'),
                    (4, 4, 1, 6, '2026-01-01', 'COMPLETED')
                """);
        execute(connection, """
                INSERT INTO media_resources
                    (id, user_id, pet_id, record_id, storage_key, original_name, content_type, extension, file_size, status)
                VALUES
                    (1, 1, 1, 1, 'records/play.jpg', 'play.jpg', 'image/jpeg', 'jpg', 10, 'STORED'),
                    (2, 1, 1, 2, 'records/sleep.jpg', 'sleep.jpg', 'image/jpeg', 'jpg', 10, 'STORED'),
                    (3, 1, 1, 3, 'records/checkup.jpg', 'checkup.jpg', 'image/jpeg', 'jpg', 10, 'STORED'),
                    (4, 1, 1, 4, 'records/meal.jpg', 'meal.jpg', 'image/jpeg', 'jpg', 10, 'STORED')
                """);
    }

    private void assertRemovalFixtures(Connection connection) throws Exception {
        assertEquals(2, count(connection, "SELECT COUNT(*) FROM record_walk WHERE record_id IN (1, 2)"));
        assertEquals(1, count(connection, "SELECT COUNT(*) FROM record_vet WHERE record_id = 3"));
        assertEquals(1, count(connection, """
                SELECT COUNT(*)
                FROM activity_records record
                JOIN record_walk walk ON walk.record_id = record.id
                WHERE record.id = 7 AND record.type_id = 'walk'
                """));
        assertEquals(1, count(connection, """
                SELECT COUNT(*)
                FROM activity_records record
                JOIN record_vet vet ON vet.record_id = record.id
                WHERE record.id = 5
                  AND record.type_id = 'vet'
                  AND vet.vet_visit_reason = 'checkup'
                """));
    }

    private void assertRemovalResult(Connection connection) throws Exception {
        assertEquals(0, count(connection, "SELECT COUNT(*) FROM activity_records WHERE type_id IN ('play', 'sleep', 'checkup')"));
        assertEquals(0, count(connection, "SELECT COUNT(*) FROM routines WHERE type_id IN ('play', 'sleep', 'checkup')"));
        assertEquals(0, count(connection, "SELECT COUNT(*) FROM routine_completions WHERE routine_id IN (1, 2, 3)"));
        assertEquals(0, count(connection, "SELECT COUNT(*) FROM media_resources WHERE storage_key IN ('records/play.jpg', 'records/sleep.jpg', 'records/checkup.jpg')"));
        assertEquals(3, count(connection, "SELECT COUNT(*) FROM media_cleanup_queue WHERE storage_key IN ('records/play.jpg', 'records/sleep.jpg', 'records/checkup.jpg')"));
        assertEquals(0, count(connection, "SELECT COUNT(*) FROM activity_types WHERE id IN ('play', 'sleep', 'checkup')"));
        assertEquals(1, count(connection, "SELECT COUNT(*) FROM activity_records WHERE id = 4 AND type_id = 'meal' AND routine_id IS NULL"));
        assertEquals(1, count(connection, "SELECT COUNT(*) FROM record_meal WHERE record_id = 4"));
        assertEquals(1, count(connection, "SELECT COUNT(*) FROM media_resources WHERE storage_key = 'records/meal.jpg'"));
        assertEquals(0, count(connection, "SELECT COUNT(*) FROM record_walk WHERE record_id IN (1, 2)"));
        assertEquals(0, count(connection, "SELECT COUNT(*) FROM record_vet WHERE record_id = 3"));
        assertEquals(0, count(connection, """
                SELECT COUNT(*)
                FROM record_walk detail
                LEFT JOIN activity_records record ON record.id = detail.record_id
                WHERE record.id IS NULL
                """));
        assertEquals(0, count(connection, """
                SELECT COUNT(*)
                FROM record_vet detail
                LEFT JOIN activity_records record ON record.id = detail.record_id
                WHERE record.id IS NULL
                """));
        assertEquals(1, count(connection, """
                SELECT COUNT(*)
                FROM activity_records record
                JOIN record_walk walk ON walk.record_id = record.id
                WHERE record.id = 7 AND record.type_id = 'walk'
                """));
        assertEquals(1, count(connection, "SELECT COUNT(*) FROM record_vet WHERE record_id = 5 AND vet_visit_reason = 'checkup'"));
        assertEquals(2, count(connection, "SELECT COUNT(*) FROM activity_types WHERE id IN ('bath', 'groom')"));
        assertEquals(2, count(connection, "SELECT COUNT(*) FROM routines WHERE type_id IN ('bath', 'groom')"));
        assertEquals(1, count(connection, "SELECT COUNT(*) FROM routine_completions WHERE routine_id = 4"));
    }

    private void execute(Connection connection, String sql) throws Exception {
        try (var statement = connection.createStatement()) {
            statement.execute(sql);
        }
    }

    private int count(Connection connection, String sql) throws Exception {
        try (var statement = connection.prepareStatement(sql);
             var result = statement.executeQuery()) {
            result.next();
            return result.getInt(1);
        }
    }
}
