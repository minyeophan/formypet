package com.formypet.notification;
import com.formypet.auth.repository.UserRepository;
import com.formypet.common.exception.ApiException;
import com.formypet.notification.dto.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.*;
import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.MulticastMessage;

@Service @RequiredArgsConstructor
public class NotificationService {
 private static final Logger log=LoggerFactory.getLogger(NotificationService.class);
 private final JdbcTemplate jdbc; private final UserRepository users;
 private static final String AGE="created_at >= DATE_SUB(CURRENT_TIMESTAMP(6), INTERVAL 30 DAY)";
 @Transactional public void create(Long recipient,Long actor,String nickname,NotificationType type,Long post,Long comment){
  if(recipient==null||recipient.equals(actor))return;
  jdbc.update("INSERT INTO notifications (recipient_user_id,actor_user_id,actor_nickname,type,post_id,comment_id,title,body,created_at) VALUES (?,?,?,?,?,?,?,?,?)",recipient,actor,nickname,type.name(),post,comment,type.name(),nickname+"님의 활동이 있습니다.",LocalDateTime.now());
 }
 @Transactional public void createReminder(Long recipient,NotificationType type,String sourceType,Long sourceId,LocalDateTime scheduledFor,String title,String body){
  if(recipient==null)return;
  int inserted=jdbc.update("INSERT IGNORE INTO notifications (recipient_user_id,type,title,body,source_type,source_id,scheduled_for,created_at) VALUES (?,?,?,?,?,?,?,?)",recipient,type.name(),title,body,sourceType,sourceId,scheduledFor,LocalDateTime.now());
  if (inserted == 1) sendPush(recipient, type, sourceId, title, body);
 }
 private void sendPush(Long recipient, NotificationType type, Long sourceId, String title, String body) {
  if (FirebaseApp.getApps().isEmpty()) return;
  List<String> tokens=jdbc.queryForList("SELECT token FROM device_tokens WHERE user_id=? AND enabled=TRUE",String.class,recipient);
  if (tokens.isEmpty()) return;
  try {
   MulticastMessage message=MulticastMessage.builder().addAllTokens(tokens)
     .setNotification(com.google.firebase.messaging.Notification.builder().setTitle(title).setBody(body).build())
     .putData("type",type.name()).putData("sourceId",Objects.toString(sourceId, ""))
     .putData("route", type == NotificationType.CARE_SCHEDULE_REMINDER ? "/routine/schedule/"+sourceId : "/routine/"+sourceId).build();
   FirebaseMessaging.getInstance().sendEachForMulticast(message);
  } catch (Exception error) { log.warn("FCM push failed for user {}", recipient, error); }
 }
 @Transactional(readOnly=true) public NotificationSettingsResponse getSettings(String email){
  Boolean enabled=jdbc.queryForObject("SELECT notification_enabled FROM users WHERE email=?",Boolean.class,email);
  return new NotificationSettingsResponse(Boolean.TRUE.equals(enabled));
 }
 @Transactional public NotificationSettingsResponse updateSettings(String email, NotificationSettingsRequest request){
  jdbc.update("UPDATE users SET notification_enabled=?, updated_at=? WHERE email=?",request.enabled(),LocalDateTime.now(),email);
  return getSettings(email);
 }
 @Transactional public int deletePendingReminders(String sourceType, Long sourceId){
  return jdbc.update("DELETE FROM notifications WHERE source_type=? AND source_id=? AND read_at IS NULL AND scheduled_for >= ?", sourceType, sourceId, LocalDateTime.now());
 }
 @Transactional(readOnly=true) public NotificationFeedResponse list(String email,String cursor,int limit){
  Long uid=users.findByEmail(email).orElseThrow().getId(); int size=Math.max(1,Math.min(limit,50)); List<Object> p=new ArrayList<>(List.of(uid));
  String sql="SELECT id,actor_user_id,actor_nickname,type,post_id,comment_id,source_type,source_id,scheduled_for,title,body,read_at,created_at FROM notifications WHERE recipient_user_id=? AND "+AGE;
  if(cursor!=null&&!cursor.isBlank()){sql+=" AND id < ?";p.add(Long.valueOf(cursor));} sql+=" ORDER BY id DESC LIMIT ?";p.add(size+1);
  List<Map<String,Object>> rows=jdbc.queryForList(sql,p.toArray()); boolean more=rows.size()>size;if(more)rows=rows.subList(0,size);List<NotificationResponse> items=rows.stream().map(this::map).toList();
  int unread=jdbc.queryForObject("SELECT COUNT(*) FROM notifications WHERE recipient_user_id=? AND read_at IS NULL AND "+AGE,Integer.class,uid);
  return new NotificationFeedResponse(items,more?items.getLast().id().toString():null,more,unread);
 }
 @Transactional public void read(String email,Long id){Long uid=users.findByEmail(email).orElseThrow().getId();if(jdbc.update("UPDATE notifications SET read_at=COALESCE(read_at,?) WHERE id=? AND recipient_user_id=? AND "+AGE,LocalDateTime.now(),id,uid)==0)throw new ApiException(HttpStatus.NOT_FOUND,"notification-not-found","Notification Not Found","Notification not found.","NOTIFICATION_NOT_FOUND");}
 @Transactional public void readAll(String email){Long uid=users.findByEmail(email).orElseThrow().getId();jdbc.update("UPDATE notifications SET read_at=? WHERE recipient_user_id=? AND read_at IS NULL AND "+AGE,LocalDateTime.now(),uid);}
 @Transactional public int cleanup(){return jdbc.update("DELETE FROM notifications WHERE created_at < DATE_SUB(CURRENT_TIMESTAMP(6), INTERVAL 30 DAY)");}
 private NotificationResponse map(Map<String,Object> r){return new NotificationResponse(((Number)r.get("id")).longValue(),num(r.get("actor_user_id")),(String)r.get("actor_nickname"),NotificationType.valueOf((String)r.get("type")),num(r.get("post_id")),num(r.get("comment_id")),(String)r.get("source_type"),num(r.get("source_id")),date(r.get("scheduled_for")),(String)r.get("title"),(String)r.get("body"),date(r.get("read_at")),date(r.get("created_at")));}
 private Long num(Object x){return x==null?null:((Number)x).longValue();} private LocalDateTime date(Object x){return x instanceof Timestamp t?t.toLocalDateTime():(LocalDateTime)x;}
}
