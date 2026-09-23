package com.formypet.support;

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

        assertEquals("31", flyway.info().current().getVersion().getVersion());
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
            assertActivityIndexes(connection);
            assertNotificationsSchema(connection);
            try (var statement = connection.createStatement()) {
                statement.executeUpdate("INSERT INTO users(email, password_hash, nickname, registration_source) VALUES ('role-default@example.test', 'hash', 'reader', 'LOCAL')");
                try (var result = statement.executeQuery("SELECT role FROM users WHERE email='role-default@example.test'")) {
                    result.next();
                    assertEquals("USER", result.getString(1));
                }
            }
            assertEquals(1, count(connection, "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'notification_enabled'"));
        }
    }

    @Test
    void addsSupportAndBlockingToExistingV27Database() throws Exception {
        flyway("27").migrate();
        try (Connection connection = connection(); var statement = connection.createStatement()) {
            statement.executeUpdate("INSERT INTO users(id,email,password_hash,nickname) VALUES (91001,'support-migration@example.test','hash','reader')");
        }
        flyway(null).migrate();
        try (Connection connection = connection()) {
            assertEquals(3, count(connection, """
                    SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE()
                    AND table_name IN ('support_tickets','support_mail_outbox','user_blocks')
                    """));
            assertEquals(1, count(connection, "SELECT COUNT(*) FROM users WHERE id=91001"));
            assertEquals(0, count(connection, "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='spatial_test'"));
            assertEquals(0, count(connection, "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=DATABASE() AND table_name='record_walk' AND column_name IN ('start_location','end_location')"));
            assertEquals(0, count(connection, "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=DATABASE() AND table_name='record_vet' AND column_name='clinic_location'"));
            try (var statement = connection.createStatement()) {
                statement.executeUpdate("""
                        INSERT INTO support_tickets(requester_user_id,kind,request_id,payload_hash,category,title,content,created_at)
                        VALUES (91001,'INQUIRY','migration',REPEAT('a',64),'BUG','test','body',UTC_TIMESTAMP(6))
                        """);
                statement.executeUpdate("INSERT INTO support_mail_outbox(ticket_id,next_attempt_at) SELECT id,UTC_TIMESTAMP(6) FROM support_tickets");
                statement.executeUpdate("DELETE FROM users WHERE id=91001");
            }
            assertEquals(1, count(connection, "SELECT COUNT(*) FROM support_tickets WHERE requester_user_id IS NULL"));
            assertEquals(1, count(connection, "SELECT COUNT(*) FROM support_mail_outbox WHERE status='PENDING'"));
        }
    }

    @Test
    void removesOnlyCoordinatesFromPopulatedV29Database() throws Exception {
        flyway("29").migrate();
        try (Connection connection = connection()) {
            execute(connection, "INSERT INTO users(id,email,password_hash,nickname) VALUES (1,'location@example.test','hash','owner')");
            execute(connection, "INSERT INTO pets(id,user_id,name,species,accent_color,bg_light) VALUES (1,1,'Maro','dog','#000000','#ffffff')");
            execute(connection, """
                    INSERT INTO routines(id,pet_id,label,type_id,repeat_type,start_date,detail) VALUES
                    (1,1,'Walk','walk','daily','2026-05-09',JSON_OBJECT('distance',2.4,'memo','park','startLng',127,'startLat',37,'endLng',128,'endLat',38,'clinicLng',129,'clinicLat',39)),
                    (2,1,'Empty','walk','daily','2026-05-09',JSON_OBJECT()),
                    (3,1,'Null','walk','daily','2026-05-09',NULL),
                    (4,1,'Array','walk','daily','2026-05-09',JSON_ARRAY('keep')),
                    (5,1,'Json null','walk','daily','2026-05-09',CAST('null' AS JSON))
                    """);
            execute(connection, """
                    INSERT INTO activity_records(id,pet_id,type_id,date,note,routine_id) VALUES
                    (1,1,'walk','2026-05-09','walk note',1),(2,1,'walk','2026-05-09','no coordinates',NULL),
                    (3,1,'vet','2026-05-09','vet note',NULL),(4,1,'vet','2026-05-09','no coordinates',NULL)
                    """);
            execute(connection, """
                    INSERT INTO record_walk(record_id,distance,duration,start_location,end_location) VALUES
                    (1,2.4,30,ST_GeomFromText('POINT(37 127)',4326),ST_GeomFromText('POINT(38 128)',4326)),
                    (2,1.2,15,NULL,NULL)
                    """);
            execute(connection, """
                    INSERT INTO record_vet(record_id,vet_clinic_name,clinic_location,vet_diagnosis,vet_cost) VALUES
                    (3,'Animal clinic',ST_GeomFromText('POINT(37 127)',4326),'checkup',12000),
                    (4,'Other clinic',NULL,'healthy',5000)
                    """);
            execute(connection, "INSERT INTO routine_completions(routine_id,pet_id,activity_record_id,scheduled_date,status) VALUES (1,1,1,'2026-05-09','COMPLETED')");
            execute(connection, """
                    INSERT INTO media_resources(user_id,pet_id,record_id,storage_key,original_name,content_type,extension,file_size,status)
                    VALUES (1,1,1,'records/walk.jpg','walk.jpg','image/jpeg','jpg',100,'STORED'),
                    (1,1,3,'records/vet.jpg','vet.jpg','image/jpeg','jpg',200,'STORED')
                    """);
        }
        Flyway latest = flyway(null);
        latest.migrate();
        latest.validate();
        try (Connection connection = connection()) {
            assertEquals(4, count(connection, "SELECT COUNT(*) FROM activity_records"));
            assertEquals(1, count(connection, "SELECT COUNT(*) FROM activity_records WHERE id=1 AND note='walk note' AND routine_id=1"));
            assertEquals(1, count(connection, "SELECT COUNT(*) FROM record_walk WHERE record_id=1 AND distance=2.4 AND duration=30"));
            assertEquals(1, count(connection, "SELECT COUNT(*) FROM record_walk WHERE record_id=2 AND distance=1.2 AND duration=15"));
            assertEquals(1, count(connection, "SELECT COUNT(*) FROM record_vet WHERE record_id=3 AND vet_clinic_name='Animal clinic' AND vet_diagnosis='checkup' AND vet_cost=12000"));
            assertEquals(1, count(connection, "SELECT COUNT(*) FROM record_vet WHERE record_id=4 AND vet_clinic_name='Other clinic' AND vet_cost=5000"));
            assertEquals(2, count(connection, "SELECT COUNT(*) FROM media_resources WHERE record_id IN (1,3) AND status='STORED'"));
            assertEquals(1, count(connection, "SELECT COUNT(*) FROM routine_completions WHERE routine_id=1 AND activity_record_id=1 AND status='COMPLETED'"));
            assertEquals(1, count(connection, "SELECT COUNT(*) FROM routines WHERE id=1 AND detail=JSON_OBJECT('distance',2.4,'memo','park')"));
            assertEquals(1, count(connection, "SELECT COUNT(*) FROM routines WHERE id=2 AND detail=JSON_OBJECT()"));
            assertEquals(1, count(connection, "SELECT COUNT(*) FROM routines WHERE id=3 AND detail IS NULL"));
            assertEquals(1, count(connection, "SELECT COUNT(*) FROM routines WHERE id=4 AND detail=JSON_ARRAY('keep')"));
            assertEquals(1, count(connection, "SELECT COUNT(*) FROM routines WHERE id=5 AND JSON_TYPE(detail)='NULL'"));
            assertEquals(0, count(connection, "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=DATABASE() AND column_name IN ('start_location','end_location','clinic_location')"));
            assertEquals(0, count(connection, "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='spatial_test'"));
        }
    }

    @Test
    void addsCommentManagementSchemaFromV20() throws Exception {
        Flyway flyway = flyway("20");
        flyway.migrate();

        flyway = flyway(null);
        flyway.migrate();

        assertEquals("31", flyway.info().current().getVersion().getVersion());
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

    private void assertActivityIndexes(Connection connection) throws Exception {
        for (String index : new String[]{"idx_posts_user_activity", "idx_likes_user_activity", "idx_comments_user_activity"}) {
            assertEquals(1, count(connection, "SELECT COUNT(DISTINCT index_name) FROM information_schema.statistics "
                    + "WHERE table_schema = DATABASE() AND index_name = '" + index + "'"));
        }
    }

    private void assertNotificationsSchema(Connection connection) throws Exception {
        assertEquals(1, count(connection, """
                SELECT COUNT(*) FROM information_schema.tables
                WHERE table_schema = DATABASE()
                  AND table_name = 'notifications'
                """));
        assertEquals(14, count(connection, """
                SELECT COUNT(*) FROM information_schema.columns
                WHERE table_schema = DATABASE()
                  AND table_name = 'notifications'
                  AND column_name IN (
                      'id', 'recipient_user_id', 'actor_user_id', 'actor_nickname',
                      'type', 'post_id', 'comment_id', 'source_type', 'source_id', 'scheduled_for',
                      'title', 'body', 'read_at', 'created_at'
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
