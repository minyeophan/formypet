package com.formypet.domain.community.service;

import com.formypet.domain.user.entity.User;
import com.formypet.domain.user.repository.UserRepository;
import com.formypet.common.exception.ApiException;
import com.formypet.domain.community.repository.PostRepository;
import com.formypet.domain.community.repository.query.PostProjectionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class CommunityAccess {
    private final UserRepository userRepository;
    private final PostRepository postRepository;
    private final PostProjectionRepository postQueries;
    public User findUser(Long actorId) {
        return userRepository.findById(actorId)
                .orElseThrow(() -> new IllegalStateException("User not found."));
    }

    public void ensurePostExists(Long postId) {
        if (!postRepository.existsById(postId)) throw postNotFound();
    }

    public void ensurePostVisible(Long postId, Long viewer) {
        if (!postQueries.visible(postId, viewer)) throw postNotFound();
    }

    public ApiException postNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "post-not-found", "Post Not Found", "Post not found.", "POST_NOT_FOUND");
    }
}
