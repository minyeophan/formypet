package com.formypet.domain.petlog.repository;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.*;

@Repository
@RequiredArgsConstructor
public class PetLogQueryRepository {
    private final JdbcTemplate jdbc;
    public record LogRow(long id, long petId, LocalDateTime entryAt, String note, long version, Instant createdAt) {}
    private static final RowMapper<LogRow> ROW = (rs, n) -> new LogRow(rs.getLong("id"), rs.getLong("pet_id"),
            rs.getObject("entry_at", LocalDateTime.class), rs.getString("note"), rs.getLong("version"),
            rs.getTimestamp("created_at").toInstant());
    private static final String SELECT = "SELECT id,pet_id,entry_at,note,version,created_at FROM pet_logs";

    public List<LogRow> list(Long petId, LocalDateTime from, LocalDateTime to,
                             LocalDateTime before, Long beforeId, int limit) {
        StringBuilder sql = new StringBuilder(SELECT + " WHERE pet_id=?");
        List<Object> args = new ArrayList<>(List.of(petId));
        if (from != null) {
            sql.append(" AND entry_at>=? AND entry_at<?"); args.add(from); args.add(to);
        }
        if (before != null) {
            sql.append(" AND (entry_at<? OR (entry_at=? AND id<?))");
            args.add(before); args.add(before); args.add(beforeId);
        }
        sql.append(" ORDER BY entry_at DESC,id DESC LIMIT ?"); args.add(limit);
        return jdbc.query(sql.toString(), ROW, args.toArray());
    }

    public Optional<LogRow> find(Long id, Long petId) {
        return jdbc.query(SELECT + " WHERE id=? AND pet_id=?", ROW, id, petId).stream().findFirst();
    }
    public List<Integer> years(Long petId) {
        return jdbc.queryForList("SELECT DISTINCT YEAR(entry_at) FROM pet_logs WHERE pet_id=? ORDER BY YEAR(entry_at) DESC", Integer.class, petId);
    }
    public boolean hasAny(Long petId) {
        return Boolean.TRUE.equals(jdbc.queryForObject("SELECT EXISTS(SELECT 1 FROM pet_logs WHERE pet_id=?)", Boolean.class, petId));
    }
}
