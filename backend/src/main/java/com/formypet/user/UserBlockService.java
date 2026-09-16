package com.formypet.user;

import com.formypet.auth.repository.UserRepository;
import com.formypet.common.exception.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

@Service
@RequiredArgsConstructor
public class UserBlockService {
    private final JdbcTemplate jdbc;
    private final UserRepository users;

    public record BlockedUser(Long userId, String nickname) {}
    public record BlockList(List<BlockedUser> items) {}

    @Transactional(readOnly = true)
    public BlockList list(String email) {
        Long viewer = userId(email);
        return new BlockList(jdbc.query("""
                SELECT u.id, u.nickname FROM user_blocks b JOIN users u ON u.id = b.blocked_user_id
                WHERE b.blocker_user_id = ? ORDER BY b.created_at DESC, b.blocked_user_id DESC
                """, (rs, row) -> new BlockedUser(rs.getLong("id"), rs.getString("nickname")), viewer));
    }

    @Transactional
    public void block(String email, Long target) {
        Long viewer = userId(email);
        if (viewer.equals(target)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "self-user-block", "Invalid User Block",
                    "You cannot block yourself.", "SELF_USER_BLOCK");
        }
        if (!users.existsById(target)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "user-not-found", "User Not Found",
                    "User not found.", "USER_NOT_FOUND");
        }
        jdbc.update("""
                INSERT INTO user_blocks (blocker_user_id, blocked_user_id) VALUES (?, ?)
                ON DUPLICATE KEY UPDATE blocked_user_id = VALUES(blocked_user_id)
                """, viewer, target);
    }

    @Transactional
    public void unblock(String email, Long target) {
        jdbc.update("DELETE FROM user_blocks WHERE blocker_user_id = ? AND blocked_user_id = ?", userId(email), target);
    }

    private Long userId(String email) {
        return users.findByEmail(email).orElseThrow(() -> new IllegalStateException("User not found.")).getId();
    }
}
