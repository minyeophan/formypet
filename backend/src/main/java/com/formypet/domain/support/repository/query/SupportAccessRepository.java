package com.formypet.domain.support.repository.query;

import java.util.Optional;
import java.util.OptionalLong;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
@RequiredArgsConstructor
public class SupportAccessRepository {
    private final JdbcTemplate jdbc;

    public OptionalLong lockUser(Long userId) {
        var ids = jdbc.queryForList("SELECT id FROM users WHERE id=? FOR UPDATE", Long.class, userId);
        return ids.isEmpty() ? OptionalLong.empty() : OptionalLong.of(ids.getFirst());
    }

    public Optional<SupportPostSnapshot> post(long postId) {
        return jdbc.query("""
                SELECT p.user_id,p.title,p.content,u.nickname
                FROM posts p JOIN users u ON u.id=p.user_id WHERE p.id=?
                """, (rs, row) -> new SupportPostSnapshot(rs.getLong("user_id"), rs.getString("title"),
                rs.getString("content"), rs.getString("nickname")), postId).stream().findFirst();
    }
}
