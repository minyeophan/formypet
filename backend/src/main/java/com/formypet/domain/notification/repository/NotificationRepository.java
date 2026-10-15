package com.formypet.domain.notification.repository;

import com.formypet.domain.notification.entity.Notification;
import com.formypet.domain.notification.repository.query.NotificationFeed;
import com.formypet.domain.notification.repository.query.NotificationVisibility;
import java.time.LocalDateTime;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface NotificationRepository extends JpaRepository<Notification, Long>, NotificationFeed {
    @Query(value = "SELECT COUNT(*) FROM notifications WHERE recipient_user_id=:recipient AND read_at IS NULL AND "
            + NotificationVisibility.AGE + " AND " + NotificationVisibility.VISIBLE, nativeQuery = true)
    int countUnreadVisible(@Param("recipient") long recipient);

    @Modifying(flushAutomatically = true)
    @Query("delete from Notification n where n.sourceType=:type and n.sourceId=:id and n.readAt is null and n.scheduledFor>=:now")
    int deletePending(@Param("type") String type, @Param("id") Long id, @Param("now") LocalDateTime now);

    @Modifying(flushAutomatically = true)
    @Query(value = "DELETE FROM notifications WHERE created_at < DATE_SUB(CURRENT_TIMESTAMP(6), INTERVAL 30 DAY)", nativeQuery = true)
    int deleteExpired();
}
