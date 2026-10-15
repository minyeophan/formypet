package com.formypet.domain.notification.repository.query;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;

/** JPA repository fragment for cross-domain visibility and direct DATETIME field extraction. */
@RequiredArgsConstructor
public class NotificationFeedImpl implements NotificationFeed {
    private final JdbcTemplate jdbc;

    @Override
    public List<NotificationRow> findVisible(long recipient, Long cursor, int size) {
        String sql = """
                SELECT id,actor_user_id,actor_nickname,type,post_id,comment_id,source_type,source_id,
                       scheduled_for,title,body,read_at,created_at
                FROM notifications WHERE recipient_user_id=? AND
                """ + NotificationVisibility.AGE + " AND " + NotificationVisibility.VISIBLE;
        List<Object> parameters = new ArrayList<>(List.of(recipient));
        if (cursor != null) {
            sql += " AND id < ?";
            parameters.add(cursor);
        }
        sql += " ORDER BY id DESC LIMIT ?";
        parameters.add(size);
        return jdbc.query(sql, (rs, row) -> new NotificationRow(rs.getLong("id"),
                rs.getObject("actor_user_id", Long.class), rs.getString("actor_nickname"), rs.getString("type"),
                rs.getObject("post_id", Long.class), rs.getObject("comment_id", Long.class), rs.getString("source_type"),
                rs.getObject("source_id", Long.class), rs.getObject("scheduled_for", LocalDateTime.class),
                rs.getString("title"), rs.getString("body"), rs.getObject("read_at", LocalDateTime.class),
                rs.getObject("created_at", LocalDateTime.class)), parameters.toArray());
    }
}
