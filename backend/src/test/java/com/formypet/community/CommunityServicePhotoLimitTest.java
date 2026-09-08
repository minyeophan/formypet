package com.formypet.community;

import com.formypet.auth.domain.User;
import com.formypet.auth.repository.UserRepository;
import com.formypet.community.dto.PostCreateRequest;
import com.formypet.media.MediaService;
import com.formypet.media.dto.MediaResponse;
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
    private final CommunityService service = new CommunityService(jdbc, users, media, notifications);
    private final User user = mock(User.class);
    private final PostCreateRequest request = new PostCreateRequest("Photos", "FREE", "Body", null, null);

    @BeforeEach
    void setUp() {
        when(users.findByEmail("author@example.test")).thenReturn(Optional.of(user));
        when(user.getId()).thenReturn(7L);
    }

    @ParameterizedTest
    @ValueSource(ints = {4, 5})
    void createsPostWithAllSelectedPhotosInOrder(int count) {
        List<Long> storedMedia = new ArrayList<>();
        when(jdbc.update(any(PreparedStatementCreator.class), any(KeyHolder.class))).thenAnswer(call -> {
            call.<KeyHolder>getArgument(1).getKeyList().add(Map.of("id", 42L));
            return 1;
        });
        when(media.uploadCommunityMedia(eq(user), any(MultipartFile.class))).thenAnswer(call -> {
            MultipartFile file = call.getArgument(1);
            long id = Long.parseLong(file.getOriginalFilename().replace(".png", ""));
            return MediaResponse.publicMedia(id, file.getOriginalFilename(), "image/png", 1, "READY");
        });
        when(jdbc.update(anyString(), eq(42L), anyLong(), anyInt())).thenAnswer(call -> {
            assertThat(call.<Integer>getArgument(3)).isEqualTo(storedMedia.size());
            storedMedia.add(call.getArgument(2));
            return 1;
        });
        Map<String, Object> row = new HashMap<>(Map.of(
                "id", 42L, "user_id", 7L, "author_nickname", "Author", "title", "Photos",
                "category", "FREE", "content", "Body", "likes_count", 0, "comments_count", 0,
                "liked", false, "created_at", LocalDateTime.of(2026, 9, 8, 12, 0)));
        when(jdbc.queryForMap(anyString(), eq(7L), eq(42L))).thenReturn(row);
        when(jdbc.queryForList(anyString(), eq(Long.class), eq(42L))).thenAnswer(call -> storedMedia);
        when(jdbc.queryForList(anyString(), eq(42L))).thenReturn(List.of());

        var response = service.create("author@example.test", request, photos(count));

        assertThat(response.mediaUrls()).containsExactlyElementsOf(
                count == 4
                        ? List.of("/api/v1/public/media/1", "/api/v1/public/media/2", "/api/v1/public/media/3", "/api/v1/public/media/4")
                        : List.of("/api/v1/public/media/1", "/api/v1/public/media/2", "/api/v1/public/media/3", "/api/v1/public/media/4", "/api/v1/public/media/5"));
    }

    @Test
    void rejectsSixPhotosBeforeWritingAnything() {
        assertThatThrownBy(() -> service.create("author@example.test", request, photos(6)))
                .isInstanceOf(IllegalArgumentException.class);
        verifyNoInteractions(jdbc, media, notifications);
    }

    private List<MultipartFile> photos(int count) {
        List<MultipartFile> files = new ArrayList<>();
        for (int i = 1; i <= count; i++) {
            files.add(new MockMultipartFile("files", i + ".png", "image/png", new byte[]{1}));
        }
        return files;
    }
}
