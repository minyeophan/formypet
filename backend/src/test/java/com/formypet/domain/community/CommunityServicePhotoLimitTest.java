package com.formypet.domain.community;

import com.formypet.domain.community.service.CommunityService;
import com.formypet.domain.community.service.impl.CommunityServiceImpl;
import com.formypet.domain.community.controller.MyActivityController;

import com.formypet.auth.domain.User;
import com.formypet.auth.repository.UserRepository;
import com.formypet.domain.community.entity.Post;
import com.formypet.domain.community.repository.PostRepository;
import com.formypet.domain.community.dto.request.PostCreateRequest;
import com.formypet.domain.media.service.MediaService;
import com.formypet.domain.media.dto.response.MediaResponse;
import com.formypet.notification.NotificationService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.PreparedStatementCreator;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

// No Spring context, datasource, filesystem storage, or live notifications.
class CommunityServicePhotoLimitTest {
    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private final UserRepository users = mock(UserRepository.class);
    private final MediaService media = mock(MediaService.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final PostRepository posts = mock(PostRepository.class);
    private final com.formypet.domain.community.repository.PostRelationsRepository relations = mock(com.formypet.domain.community.repository.PostRelationsRepository.class);
    private final com.formypet.domain.community.repository.query.PostProjectionRepository queries =
            new com.formypet.domain.community.repository.query.PostProjectionRepository(jdbc);
    private final com.formypet.domain.community.service.PostService service =
            new com.formypet.domain.community.service.impl.PostServiceImpl(
                    new com.formypet.domain.community.service.CommunityAccess(users, posts, queries),
                    media, posts, relations, queries);
    private final User user = mock(User.class);
    private final PostCreateRequest request = new PostCreateRequest("Photos", "FREE", "Body", null, null);

    @BeforeEach
    void setUp() {
        when(users.findById(7L)).thenReturn(Optional.of(user));
        when(user.getId()).thenReturn(7L);
    }

    @ParameterizedTest
    @ValueSource(ints = {4, 5})
    void createsPostWithAllSelectedPhotosInOrder(int count) {
        List<Long> storedMedia = new ArrayList<>();
        when(posts.saveAndFlush(any(Post.class))).thenAnswer(call -> {
            Post post = call.getArgument(0);
            org.springframework.test.util.ReflectionTestUtils.setField(post, "id", 42L);
            return post;
        });
        when(media.uploadCommunityMedia(eq(user), anyList())).thenAnswer(call -> {
            List<MultipartFile> files = call.getArgument(1);
            return files.stream().map(file -> {
                long id = Long.parseLong(file.getOriginalFilename().replace(".png", ""));
                return MediaResponse.publicMedia(id, file.getOriginalFilename(), "image/png", 1, "READY");
            }).toList();
        });
        doAnswer(call -> {
            com.formypet.domain.community.entity.PostMedia link = call.getArgument(0);
            assertThat(link.getPostId()).isEqualTo(42L);
            assertThat(link.getSortOrder()).isEqualTo(storedMedia.size());
            storedMedia.add(link.getMediaId());
            return null;
        }).when(relations).addMedia(any(com.formypet.domain.community.entity.PostMedia.class));
        Map<String, Object> row = new HashMap<>(Map.of(
                "id", 42L, "user_id", 7L, "author_nickname", "Author", "title", "Photos",
                "category", "FREE", "content", "Body", "likes_count", 0, "comments_count", 0,
                "liked", false, "created_at", LocalDateTime.of(2026, 9, 8, 12, 0)));
        when(jdbc.queryForMap(anyString(), eq(7L), eq(42L))).thenReturn(row);
        when(jdbc.queryForList(anyString(), eq(Long.class), eq(42L))).thenAnswer(call -> storedMedia);
        when(jdbc.queryForList(anyString(), eq(42L))).thenReturn(List.of());

        var response = service.create(7L, request, photos(count));

        assertThat(response.mediaUrls()).containsExactlyElementsOf(
                count == 4
                        ? List.of("/api/v1/public/media/1", "/api/v1/public/media/2", "/api/v1/public/media/3", "/api/v1/public/media/4")
                        : List.of("/api/v1/public/media/1", "/api/v1/public/media/2", "/api/v1/public/media/3", "/api/v1/public/media/4", "/api/v1/public/media/5"));
    }

    @Test
    void rejectsSixPhotosBeforeWritingAnything() {
        assertThatThrownBy(() -> service.create(7L, request, photos(6)))
                .isInstanceOf(IllegalArgumentException.class);
        verifyNoInteractions(jdbc, media, notifications, posts, relations);
    }

    private List<MultipartFile> photos(int count) {
        List<MultipartFile> files = new ArrayList<>();
        for (int i = 1; i <= count; i++) {
            files.add(new MockMultipartFile("files", i + ".png", "image/png", new byte[]{1}));
        }
        return files;
    }
}
