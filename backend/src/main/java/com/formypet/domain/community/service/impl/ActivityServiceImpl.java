package com.formypet.domain.community.service.impl;

import com.formypet.domain.user.entity.User;
import com.formypet.domain.community.entity.*;
import com.formypet.common.exception.InvalidInputException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;

import com.formypet.domain.community.service.*;
import com.formypet.domain.community.repository.*;
import com.formypet.domain.community.repository.query.*;
import com.formypet.domain.community.repository.jdbc.*;

@Service
@RequiredArgsConstructor
public class ActivityServiceImpl implements ActivityService {

    private final CommunityAccess access;
    private final PostProjectionRepository postQueries;

    @Transactional(readOnly = true)
    public com.formypet.domain.community.dto.response.MyActivityResponse myActivities(
            Long actorId, String type, String cursor, int limit) {
        User user = access.findUser(actorId);
        if (type == null || !Set.of("written", "liked", "commented").contains(type)
                || limit < 1 || limit > 50) throw InvalidInputException.invalidInput();
        LocalDateTime cursorAt = null;
        Long cursorId = null;
        if (cursor != null) {
            try {
                if (cursor.length() > 256) throw new IllegalArgumentException();
                String[] parts = new String(Base64.getUrlDecoder().decode(cursor),
                        java.nio.charset.StandardCharsets.UTF_8).split("\\|", -1);
                if (parts.length != 3 || !parts[0].equals(type)) throw new IllegalArgumentException();
                cursorAt = LocalDateTime.parse(parts[1]);
                cursorId = Long.parseLong(parts[2]);
                if (cursorId <= 0) throw new IllegalArgumentException();
            } catch (RuntimeException ex) {
                throw InvalidInputException.invalidInput();
            }
        }
        return postQueries.myActivities(user.getId(), type, cursorAt, cursorId, limit);
    }
}
