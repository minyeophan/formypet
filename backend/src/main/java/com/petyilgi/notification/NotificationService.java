package com.petyilgi.notification;

import com.petyilgi.auth.repository.UserRepository;
import com.petyilgi.common.exception.ApiException;
import com.petyilgi.notification.dto.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.LocalDateTime;
import java.util.*;

@Slf4j @Service @RequiredArgsConstructor
public class NotificationService {
    private final JdbcTemplate jdbc;
    private final UserRepository users;
    private static final String AGE = "created_at >= DATE_SUB(CURRENT_TIMESTAMP(6), INTERVAL 30 DAY)";

    @Transactional
    public void create(Long recipient, Long actor, String nickname, NotificationType type, Long post, Long comment) {
        if (recipient == null || recipient.equals(actor)) return;
        try {
            String title = switch (type) { case COMMENT -> "새 댓글"; case REPLY -> "새 답글"; case POST_LIKE -> "게시글 좋아요"; case POLL_VOTE -> "게시글 투표"; };
            String body = nickname + switch (type) { case COMMENT -> "님이 게시글에 댓글을 남겼습니다."; case REPLY -> "님이 회원님의 댓글에 답글을 남겼습니다."; case POST_LIKE -> "님이 회원님의 게시글을 좋아합니다."; case POLL_VOTE -> "님이 회원님의 게시글에 투표했습니다."; };
            jdbc.update("INSERT INTO notifications (recipient_user_id, actor_user_id, actor_nickname, type, post_id, comment_id, title, body, created_at) VALUES (?,?,?,?,?,?,?,?,?)",
                    recipient, actor, nickname, type.name(), post, comment, title, body, LocalDateTime.now());
        } catch (Exception e) { log.warn("Notification creation failed; continuing core operation", e); }
    }
    @Transactional(readOnly=true)
    public NotificationFeedResponse list(String email, String cursor, int limit) {
        Long uid = users.findByEmail(email).orElseThrow().getId(); int size=Math.max(1,Math.min(limit,50));
        List<Object> p=new ArrayList<>(List.of(uid)); String sql="SELECT id,actor_user_id,actor_nickname,type,post_id,comment_id,title,body,read_at,created_at FROM notifications WHERE recipient_user_id=? AND "+AGE;
        if(cursor!=null&&!cursor.isBlank()){sql+=" AND id < ?";p.add(Long.valueOf(cursor));} sql+=" ORDER BY id DESC LIMIT ?";p.add(size+1);
        List<Map<String,Object>> rows=jdbc.queryForList(sql,p.toArray()); boolean more=rows.size()>size; if(more) rows=rows.subList(0,size);
        List<NotificationResponse> items=rows.stream().map(this::map).toList(); int unread=jdbc.queryForObject("SELECT COUNT(*) FROM notifications WHERE recipient_user_id=? AND read_at IS NULL AND "+AGE,Integer.class,uid);
        return new NotificationFeedResponse(items,more?items.getLast().id().toString():null,more,unread);
    }
    @Transactional public void read(String email, Long id){ Long uid=users.findByEmail(email).orElseThrow().getId(); int n=jdbc.update("UPDATE notifications SET read_at=COALESCE(read_at,?) WHERE id=? AND recipient_user_id=? AND "+AGE,LocalDateTime.now(),id,uid); if(n==0) throw new ApiException(HttpStatus.NOT_FOUND,"notification-not-found","Notification Not Found","Notification not found.","NOTIFICATION_NOT_FOUND"); }
    @Transactional public void readAll(String email){Long uid=users.findByEmail(email).orElseThrow().getId();jdbc.update("UPDATE notifications SET read_at=? WHERE recipient_user_id=? AND read_at IS NULL AND "+AGE,LocalDateTime.now(),uid);}
    @Transactional public int cleanup(){return jdbc.update("DELETE FROM notifications WHERE created_at < DATE_SUB(CURRENT_TIMESTAMP(6), INTERVAL 30 DAY)");}
    private NotificationResponse map(Map<String,Object> r){return new NotificationResponse(((Number)r.get("id")).longValue(),((Number)r.get("actor_user_id")).longValue(),(String)r.get("actor_nickname"),NotificationType.valueOf((String)r.get("type")),((Number)r.get("post_id")).longValue(),r.get("comment_id")==null?null:((Number)r.get("comment_id")).longValue(),(String)r.get("title"),(String)r.get("body"),toDate(r.get("read_at")),toDate(r.get("created_at")));}
    private LocalDateTime toDate(Object x){return x instanceof java.sql.Timestamp t?t.toLocalDateTime():(LocalDateTime)x;}
}
