package com.formypet.domain.user;

import com.formypet.domain.user.entity.User;
import com.formypet.domain.user.repository.UserRepository;
import com.formypet.support.IntegrationTestSupport;
import jakarta.persistence.EntityManager;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import static org.assertj.core.api.Assertions.assertThat;

@Transactional
class UserPersistenceIntegrationTest extends IntegrationTestSupport {
    @Autowired UserRepository users;
    @Autowired EntityManager entities;
    @Autowired JdbcTemplate jdbc;

    @Test void profileFlushPreservesAuthenticationVersionAndMediaCountersChangedByJdbc() {
        var user = users.saveAndFlush(User.create(UUID.randomUUID() + "@example.test", "hash", "before"));
        var createdAt = jdbc.queryForObject("SELECT created_at FROM users WHERE id=?", String.class, user.getId());
        jdbc.update("UPDATE users SET auth_version=7,media_bytes_used=12345,media_items_used=3 WHERE id=?", user.getId());
        assertThat(user.getAuthVersion()).isZero();
        assertThat(user.getMediaBytesUsed()).isZero();

        user.updateNickname("after");
        users.flush();
        entities.clear();

        var reloaded = users.findById(user.getId()).orElseThrow();
        assertThat(reloaded.getNickname()).isEqualTo("after");
        assertThat(reloaded.getAuthVersion()).isEqualTo(7);
        assertThat(reloaded.getMediaBytesUsed()).isEqualTo(12345);
        assertThat(reloaded.getMediaItemsUsed()).isEqualTo(3);
        assertThat(jdbc.queryForObject("SELECT created_at FROM users WHERE id=?", String.class, user.getId()))
                .isEqualTo(createdAt);
    }
}
