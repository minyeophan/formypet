package com.formypet.user;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.formypet.auth.repository.UserRepository;
import com.formypet.community.CommunityService;
import com.formypet.community.dto.PostCommentCreateRequest;
import com.formypet.community.dto.PostCreateRequest;
import com.formypet.common.exception.ApiException;
import com.formypet.notification.NotificationService;
import com.formypet.notification.NotificationType;
import com.formypet.support.IntegrationTestSupport;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@AutoConfigureMockMvc
@Transactional
class UserBlockingIntegrationTest extends IntegrationTestSupport {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper mapper;
    @Autowired UserRepository users;
    @Autowired JdbcTemplate jdbc;
    @Autowired CommunityService community;
    @Autowired NotificationService notifications;
    private final String keyword = "block" + UUID.randomUUID().toString().substring(0, 8);
    record Person(String email, String token, Long id) {}
    private Person person() throws Exception {
        String email = UUID.randomUUID() + "@example.com";
        var result = mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(Map.of("email", email, "password", "Password1!", "nickname", "tester"))))
                .andExpect(status().isCreated()).andReturn();
        return new Person(email, mapper.readTree(result.getResponse().getContentAsString()).path("data").path("accessToken").asText(),
                users.findByEmail(email).orElseThrow().getId());
    }
    private void block(Person viewer, Person author) throws Exception {
        mvc.perform(put("/api/v1/users/me/blocks/{id}", author.id()).header("Authorization", "Bearer " + viewer.token()))
                .andExpect(status().isNoContent());
    }
    private Long postFor(Person author) {
        return community.create(author.id(), new PostCreateRequest(keyword, "FREE", "body", null, null), List.of()).id();
    }
    @Test void blockEndpointsAreAuthenticatedValidatedAndIdempotent() throws Exception {
        Person a = person(), b = person();
        mvc.perform(get("/api/v1/users/me/blocks")).andExpect(status().isUnauthorized());
        mvc.perform(put("/api/v1/users/me/blocks/{id}", b.id())).andExpect(status().isUnauthorized());
        mvc.perform(delete("/api/v1/users/me/blocks/{id}", b.id())).andExpect(status().isUnauthorized());
        block(a,b); block(a,b);
        mvc.perform(get("/api/v1/users/me/blocks").header("Authorization", "Bearer " + b.token()))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.items", hasSize(0)));
        mvc.perform(get("/api/v1/users/me/blocks").header("Authorization", "Bearer " + a.token()))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.items", hasSize(1)))
                .andExpect(jsonPath("$.data.items[0].userId").value(b.id()))
                .andExpect(jsonPath("$.data.items[0].nickname").value("tester"));
        mvc.perform(put("/api/v1/users/me/blocks/{id}", a.id()).header("Authorization", "Bearer " + a.token())).andExpect(status().isBadRequest());
        mvc.perform(put("/api/v1/users/me/blocks/9223372036854775807").header("Authorization", "Bearer " + a.token())).andExpect(status().isNotFound());
        for (int i=0;i<2;i++) mvc.perform(delete("/api/v1/users/me/blocks/{id}", b.id()).header("Authorization", "Bearer " + a.token())).andExpect(status().isNoContent());
        mvc.perform(get("/api/v1/users/me/blocks").header("Authorization", "Bearer " + a.token())).andExpect(jsonPath("$.data.items", hasSize(0)));
    }
    @Test void hidesPostsBeforePaginationAndActivityButKeepsDirectionAndDeleteRights() throws Exception {
        Person viewer=person(), author=person();
        Long older=postFor(viewer), visible=postFor(viewer), hidden=postFor(author);
        community.toggleLike(viewer.id(), hidden);
        var ownComment=community.createComment(viewer.id(), hidden, new PostCommentCreateRequest("own", null));
        block(viewer,author);
        for(String sort:List.of("latest","popular")) {
            var feed=community.feed(viewer.id(), keyword, null, sort, null, 1);
            assertEquals(visible,feed.items().getFirst().id());
            assertNotNull(feed.nextCursor());
            var next=community.feed(viewer.id(),keyword,null,sort,feed.nextCursor(),1);
            assertEquals(older,next.items().getFirst().id()); assertNull(next.nextCursor());
        }
        assertEquals(visible,community.feed(viewer.id(),null,"FREE","latest",null,1).items().getFirst().id());
        assertEquals(visible,community.myActivities(viewer.id(),"written",null,1).items().getFirst().post().id());
        for(String activity:List.of("liked","commented")) assertTrue(community.myActivities(viewer.id(),activity,null,10).items().isEmpty());
        assertEquals("POST_NOT_FOUND",assertThrows(ApiException.class,()->community.detail(viewer.id(),hidden)).errorCode());
        mvc.perform(get("/api/v1/posts/{id}",hidden).header("Authorization","Bearer "+viewer.token())).andExpect(status().isNotFound());
        assertThrows(ApiException.class,()->community.comments(viewer.id(),hidden,null,20,20));
        assertThrows(ApiException.class,()->community.commentThread(viewer.id(),hidden,ownComment.id(),20));
        assertThrows(ApiException.class,()->community.replies(viewer.id(),hidden,ownComment.id(),null,20));
        assertThrows(ApiException.class,()->community.createComment(viewer.id(),hidden,new PostCommentCreateRequest("new",null)));
        assertThrows(ApiException.class,()->community.createComment(viewer.id(),hidden,new PostCommentCreateRequest("reply",ownComment.id())));
        community.toggleLike(viewer.id(),hidden); // removing an existing like remains possible
        assertThrows(ApiException.class,()->community.toggleLike(viewer.id(),hidden));
        assertEquals(visible,community.detail(author.id(),visible).id());
        community.deleteComment(viewer.id(),hidden,ownComment.id());
        community.delete(author.id(),hidden);
    }
    @Test void masksRootsAndRepliesOnEveryReadWithoutLosingOtherReplies() throws Exception {
        Person viewer=person(), blocked=person(); Long post=postFor(viewer);
        var root=community.createComment(blocked.id(),post,new PostCommentCreateRequest("secret root",null));
        var hidden=community.createComment(blocked.id(),post,new PostCommentCreateRequest("secret reply",root.id()));
        var own=community.createComment(viewer.id(),post,new PostCommentCreateRequest("visible reply",root.id()));
        block(viewer,blocked);
        var thread=community.commentThread(viewer.id(),post,root.id(),20);
        assertNull(thread.userId()); assertNull(thread.authorNickname()); assertNull(thread.content()); assertNull(thread.authorProfileImageUrl());
        assertFalse(thread.deleted()); assertTrue(thread.blocked());
        assertEquals(2,thread.replies().size()); assertNull(thread.replies().getFirst().content());
        assertTrue(thread.replies().getFirst().blocked()); assertFalse(thread.replies().getFirst().deleted());
        assertEquals("visible reply",thread.replies().getLast().content());
        assertFalse(thread.replies().getLast().blocked()); assertFalse(thread.replies().getLast().deleted());
        assertNull(community.comments(viewer.id(),post,null,20,20).items().getFirst().content());
        var replies=community.replies(viewer.id(),post,root.id(),null,20).items();
        assertEquals(root.id(),replies.getFirst().parentCommentId()); assertNull(replies.getFirst().userId());
        assertTrue(replies.getFirst().blocked()); assertFalse(replies.getFirst().deleted());
        assertEquals(own.id(),replies.getLast().id());
        var first=community.commentThread(viewer.id(),post,root.id(),1);
        assertEquals(2,first.replyCount()); assertNotNull(first.repliesNextCursor());
        var previous=community.replies(viewer.id(),post,root.id(),first.repliesNextCursor(),1);
        assertEquals(hidden.id(),previous.items().getFirst().id()); assertNull(previous.items().getFirst().content());
        assertEquals("secret root",community.commentThread(blocked.id(),post,root.id(),20).content());
        community.deleteComment(viewer.id(),post,hidden.id()); // post owner can still moderate
        community.deleteComment(blocked.id(),post,root.id()); // reverse direction remains usable
        var deleted=community.commentThread(viewer.id(),post,root.id(),20);
        assertTrue(deleted.deleted()); assertFalse(deleted.blocked());
        assertNull(deleted.userId()); assertNull(deleted.content());
        assertEquals(own.id(),deleted.replies().getFirst().id());
    }
    @Test void suppressesNewAndFiltersExistingNotificationsIncludingReadOperations() throws Exception {
        Person viewer=person(), blocked=person(), other=person();
        Long ownPost=postFor(viewer), blockedPost=postFor(blocked);
        notifications.create(viewer.id(),other.id(),"other",NotificationType.COMMENT,ownPost,null);
        notifications.create(viewer.id(),blocked.id(),"secret",NotificationType.COMMENT,ownPost,null);
        notifications.create(viewer.id(),other.id(),"other",NotificationType.COMMENT,blockedPost,null);
        List<Long> hidden=jdbc.queryForList("SELECT id FROM notifications WHERE recipient_user_id=? AND (actor_user_id=? OR post_id=?)",Long.class,viewer.id(),blocked.id(),blockedPost);
        block(viewer,blocked);
        notifications.create(viewer.id(),blocked.id(),"secret",NotificationType.COMMENT,ownPost,null);
        notifications.create(viewer.id(),other.id(),"other",NotificationType.COMMENT,blockedPost,null);
        assertEquals(3,jdbc.queryForObject("SELECT COUNT(*) FROM notifications WHERE recipient_user_id=?",Integer.class,viewer.id()));
        var feed=notifications.list(viewer.id(),null,1);
        assertEquals(1,feed.items().size()); assertEquals(1,feed.unreadCount()); assertNull(feed.nextCursor());
        mvc.perform(get("/api/v1/notifications").param("limit","1").header("Authorization","Bearer "+viewer.token()))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.items",hasSize(1)))
                .andExpect(jsonPath("$.data.unreadCount").value(1));
        for(Long id:hidden) assertThrows(ApiException.class,()->notifications.read(viewer.id(),id));
        mvc.perform(patch("/api/v1/notifications/{id}/read",hidden.getFirst()).header("Authorization","Bearer "+viewer.token()))
                .andExpect(status().isNotFound());
        mvc.perform(post("/api/v1/notifications/read-all").header("Authorization","Bearer "+viewer.token()))
                .andExpect(status().isOk());
        assertEquals(0,notifications.list(viewer.id(),null,20).unreadCount());
        assertEquals(2,jdbc.queryForObject("SELECT COUNT(*) FROM notifications WHERE recipient_user_id=? AND read_at IS NULL",Integer.class,viewer.id()));
    }

    @Test void unblockRestoresPostsCommentsAndOldNotifications() throws Exception {
        Person viewer=person(), author=person();
        Long hidden=postFor(author), own=postFor(viewer);
        var comment=community.createComment(author.id(),own,new PostCommentCreateRequest("restored",null));
        block(viewer,author);
        assertNull(community.commentThread(viewer.id(),own,comment.id(),20).content());
        mvc.perform(delete("/api/v1/users/me/blocks/{id}",author.id()).header("Authorization","Bearer "+viewer.token())).andExpect(status().isNoContent());
        assertEquals(hidden,community.detail(viewer.id(),hidden).id());
        assertEquals("restored",community.commentThread(viewer.id(),own,comment.id(),20).content());
        assertFalse(community.commentThread(viewer.id(),own,comment.id(),20).blocked());
        assertEquals(1,notifications.list(viewer.id(),null,20).unreadCount());
    }

    @Test void activityPaginationSkipsHiddenPostsAndRemindersRemainVisible() throws Exception {
        Person viewer=person(), author=person();
        Long older=postFor(viewer), visible=postFor(viewer), hidden=postFor(author);
        for(Long post:List.of(older,visible,hidden)) {
            community.toggleLike(viewer.id(),post);
            community.createComment(viewer.id(),post,new PostCommentCreateRequest("own",null));
        }
        block(viewer,author);
        for(String type:List.of("liked","commented")) {
            var first=community.myActivities(viewer.id(),type,null,1);
            assertEquals(visible,first.items().getFirst().post().id()); assertNotNull(first.nextCursor());
            var next=community.myActivities(viewer.id(),type,first.nextCursor(),1);
            assertEquals(older,next.items().getFirst().post().id()); assertNull(next.nextCursor());
        }
        notifications.createReminder(viewer.id(),NotificationType.CARE_SCHEDULE_REMINDER,"CARE_SCHEDULE",123L,
                java.time.LocalDateTime.now().plusHours(1),"reminder","visible");
        var reminder=notifications.list(viewer.id(),null,20);
        assertEquals(1,reminder.items().size()); assertEquals(1,reminder.unreadCount());
        notifications.read(viewer.id(),reminder.items().getFirst().id());
        assertEquals(0,notifications.list(viewer.id(),null,20).unreadCount());
    }

    @Test void blockedPostVoteCannotCreateOrChangeVoteAndReverseDirectionStillWorks() throws Exception {
        Person viewer=person(), author=person();
        var pollPost=community.create(author.id(),new PostCreateRequest(keyword,"FREE","body",null,
                new PostCreateRequest.PollCreateRequest("which",List.of("one","two"))),List.of());
        List<Long> options=jdbc.queryForList("SELECT o.id FROM post_poll_options o JOIN post_polls p ON p.id=o.poll_id WHERE p.post_id=? ORDER BY o.sort_order",Long.class,pollPost.id());
        block(viewer,author);
        assertEquals("POST_NOT_FOUND",assertThrows(ApiException.class,()->community.vote(viewer.id(),pollPost.id(),options.getFirst())).errorCode());
        assertEquals(0,jdbc.queryForObject("SELECT COUNT(*) FROM post_poll_votes WHERE user_id=?",Integer.class,viewer.id()));
        mvc.perform(delete("/api/v1/users/me/blocks/{id}",author.id()).header("Authorization","Bearer "+viewer.token())).andExpect(status().isNoContent());
        community.vote(viewer.id(),pollPost.id(),options.getFirst());
        block(viewer,author);
        assertThrows(ApiException.class,()->community.vote(viewer.id(),pollPost.id(),options.getLast()));
        assertEquals(options.getFirst(),jdbc.queryForObject("SELECT option_id FROM post_poll_votes WHERE user_id=?",Long.class,viewer.id()));
        Long ownPost=postFor(viewer);
        community.toggleLike(author.id(),ownPost);
        assertEquals(1,community.detail(author.id(),ownPost).likesCount());
        assertTrue(notifications.list(viewer.id(),null,20).items().isEmpty());
    }
}
