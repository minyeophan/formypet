package com.formypet.domain.record.repository;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;
import java.util.*;

/** Read-only media projection; media ownership and deletion remain with MediaService. */
@Repository
@RequiredArgsConstructor
public class RecordMediaQueryRepository {
    private final NamedParameterJdbcTemplate jdbc;

    public Map<Long, List<String>> findMediaUrls(List<Long> recordIds) {
        Map<Long, List<String>> result = new HashMap<>();
        for (int offset = 0; offset < recordIds.size(); offset += 500) {
            var batch = recordIds.subList(offset, Math.min(offset + 500, recordIds.size()));
            jdbc.query("SELECT id, record_id FROM media_resources WHERE record_id IN (:ids) ORDER BY id",
                    Map.of("ids", batch), (org.springframework.jdbc.core.RowCallbackHandler) rs ->
                            result.computeIfAbsent(rs.getLong("record_id"), ignored -> new ArrayList<>())
                                    .add("/api/v1/media/" + rs.getLong("id")));
        }
        return result;
    }
}
