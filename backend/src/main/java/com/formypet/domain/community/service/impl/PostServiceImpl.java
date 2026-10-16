package com.formypet.domain.community.service.impl;

import com.formypet.domain.user.entity.User;
import com.formypet.domain.community.entity.*;
import com.formypet.domain.community.repository.PostRelationsRepository;
import com.formypet.domain.community.repository.PostRepository;
import com.formypet.domain.community.dto.request.PostCreateRequest;
import com.formypet.domain.community.dto.response.PostFeedResponse;
import com.formypet.domain.community.dto.response.PostResponse;
import com.formypet.domain.community.dto.request.PostUpdateRequest;
import com.formypet.domain.media.service.MediaService;
import com.formypet.domain.media.dto.response.MediaResponse;
import com.formypet.global.exception.ForbiddenException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.util.*;

import com.formypet.domain.community.service.*;
import com.formypet.domain.community.repository.*;
import com.formypet.domain.community.repository.query.*;
import com.formypet.domain.community.repository.jdbc.*;

@Service
@RequiredArgsConstructor
public class PostServiceImpl implements PostService {
    private static final Set<String> SORTS = Set.of("latest", "popular");
    private final CommunityAccess access;
    private final MediaService mediaService;
    private final PostRepository postRepository;
    private final PostRelationsRepository relations;
    private final PostProjectionRepository postQueries;

    @Transactional
    public PostResponse create(Long actorId, PostCreateRequest request, List<MultipartFile> files) {
        User user = access.findUser(actorId);
        validateCreate(request, files);
        requireCategoryWritePermission(user, normalizeCategory(request.category()));
        Post post = postRepository.saveAndFlush(Post.create(user.getId(), request.title(), request.category(),
                request.petSpecies(), request.content()));
        Long postId = post.getId();
        insertMedia(user, postId, files);
        insertPoll(postId, request.poll());
        return postQueries.findPostResponse(postId, user.getId());
    }

    @Transactional(readOnly = true)
    public PostFeedResponse feed(Long actorId, String keyword, String category, String sort, String cursor, int limit) {
        User user = access.findUser(actorId);
        String normalizedSort = SORTS.contains(sort) ? sort : "latest";
        String normalizedKeyword = normalizeKeyword(keyword);
        int pageSize = Math.max(1, Math.min(limit, 50));
        String normalizedCategory = category == null || category.isBlank() ? null : normalizeCategory(category);
        Integer cursorLikes = null;
        Long cursorId = null;
        if (cursor != null && !cursor.isBlank()) {
            if ("popular".equals(normalizedSort)) {
                String[] parts = cursor.split(":", 2);
                if (parts.length != 2) throw new IllegalArgumentException("Invalid popular cursor.");
                cursorLikes = Integer.parseInt(parts[0]);
                cursorId = Long.parseLong(parts[1]);
            } else {
                cursorId = Long.parseLong(cursor);
            }
        }
        return postQueries.feed(user.getId(), normalizedKeyword, normalizedCategory, normalizedSort,
                cursorLikes, cursorId, pageSize);
    }

    @Transactional(readOnly = true)
    public PostResponse detail(Long actorId, Long postId) {
        User user = access.findUser(actorId);
        access.ensurePostVisible(postId, user.getId());
        return postQueries.findPostResponse(postId, user.getId());
    }

    @Transactional
    public PostResponse update(Long actorId, Long postId, PostUpdateRequest request) {
        User user = access.findUser(actorId);
        access.ensurePostExists(postId);
        Post post = postRepository.findById(postId).orElseThrow(access::postNotFound);
        if (!user.getId().equals(post.getUserId())) {
            throw new ForbiddenException("Forbidden post.", "POST_FORBIDDEN");
        }
        Post.validateUpdate(request.title(), request.category(), request.content());
        requireCategoryWritePermission(user, normalizeCategory(request.category()));
        requireCategoryWritePermission(user, post.getCategory());
        post.update(request.title(), request.category(), request.petSpecies(), request.content());
        postRepository.flush();
        return postQueries.findPostResponse(postId, user.getId());
    }

    @Transactional
    public void delete(Long actorId, Long postId) {
        User user = access.findUser(actorId);
        access.ensurePostExists(postId);
        Post post = postRepository.findById(postId).orElseThrow(access::postNotFound);
        if (!user.getId().equals(post.getUserId())) {
            throw new ForbiddenException("Forbidden post.", "POST_FORBIDDEN");
        }
        List<Long> mediaIds = relations.mediaIds(postId);
        postRepository.delete(post);
        postRepository.flush();
        for (Long mediaId : mediaIds) {
            if (!relations.mediaHasReferences(mediaId)) {
                mediaService.deleteCommunityMedia(user.getId(), mediaId);
            }
        }
    }

    private void validateCreate(PostCreateRequest request, List<MultipartFile> files) {
        Post.validateCreate(request.title(), request.category(), request.content());
        if (files.size() > 5) throw new IllegalArgumentException("A post can include up to 5 images.");
        if (request.poll() != null) PostPoll.validate(request.poll().question(), request.poll().options());
    }

    private void insertMedia(User user, Long postId, List<MultipartFile> files) {
        List<MediaResponse> uploaded = mediaService.uploadCommunityMedia(user, files);
        for (int i = 0; i < uploaded.size(); i++) {
            relations.addMedia(PostMedia.create(postId, uploaded.get(i).id(), i));
        }
        relations.flush();
    }

    private void insertPoll(Long postId, PostCreateRequest.PollCreateRequest request) {
        if (request == null) return;
        PostPoll poll = PostPoll.create(postId, request.question());
        relations.addPoll(poll);
        for (int i = 0; i < request.options().size(); i++) {
            relations.addOption(PostPollOption.create(poll.getId(), request.options().get(i), i));
        }
        relations.flush();
    }

    private String normalizeKeyword(String keyword) {
        if (keyword == null) {
            return null;
        }
        String normalized = keyword.strip();
        if (normalized.isEmpty()) {
            return null;
        }
        int length = normalized.codePointCount(0, normalized.length());
        if (length < 2 || length > 20) {
            throw new IllegalArgumentException("Search keyword must be between 2 and 20 characters.");
        }
        return normalized;
    }

    private void requireCategoryWritePermission(User user, String category) {
        if ("NEWS".equals(category) && !user.isAdmin()) {
            throw new ForbiddenException("소식은 관리자만 작성할 수 있습니다.", "NEWS_ADMIN_ONLY");
        }
    }

    private String normalizeCategory(String category) {
        return Post.normalizeCategory(category);
    }
}
