package com.formypet.domain.user.repository;

import com.formypet.domain.user.entity.User;

import com.formypet.domain.user.entity.UserBlock;
import com.formypet.domain.user.entity.UserBlockId;
import com.formypet.domain.user.repository.query.BlockedUserRow;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface UserBlockRepository extends JpaRepository<UserBlock, UserBlockId> {
    @Query("""
            SELECT new com.formypet.domain.user.repository.query.BlockedUserRow(u.id, u.nickname)
            FROM UserBlock b JOIN User u ON u.id=b.id.blockedUserId
            WHERE b.id.blockerUserId=:actor
            ORDER BY b.createdAt DESC, b.id.blockedUserId DESC
            """)
    List<BlockedUserRow> listBlocked(@Param("actor") Long actor);

    // Atomic duplicate handling preserves the original creation time, including concurrent requests.
    @Modifying(flushAutomatically = true)
    @Query(value = """
            INSERT INTO user_blocks(blocker_user_id,blocked_user_id) VALUES (:actor,:target)
            ON DUPLICATE KEY UPDATE blocked_user_id=VALUES(blocked_user_id)
            """, nativeQuery = true)
    int addIfAbsent(@Param("actor") Long actor, @Param("target") Long target);

    @Modifying(flushAutomatically = true)
    @Query("DELETE FROM UserBlock b WHERE b.id.blockerUserId=:actor AND b.id.blockedUserId=:target")
    int remove(@Param("actor") Long actor, @Param("target") Long target);
}
