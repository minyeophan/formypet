package com.formypet.domain.community.service.impl;

import com.formypet.auth.domain.User;
import com.formypet.domain.community.entity.*;
import com.formypet.domain.community.repository.PostRelationsRepository;
import com.formypet.domain.community.repository.jdbc.PostCounterRepository;
import com.formypet.domain.community.dto.response.PostLikeResponse;
import com.formypet.domain.community.dto.response.PostResponse;
import com.formypet.notification.NotificationService;
import com.formypet.notification.NotificationType;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

import com.formypet.domain.community.service.*;
import com.formypet.domain.community.repository.*;
import com.formypet.domain.community.repository.query.*;
import com.formypet.domain.community.repository.jdbc.*;

@Service
@RequiredArgsConstructor
public class ReactionServiceImpl implements ReactionService {

    private final CommunityAccess access;
    private final PostRelationsRepository relations;
    private final ReactionInsertRepository reactionInserts;
    private final PostCounterRepository counters;
    private final PostProjectionRepository postQueries;
    private final NotificationService notificationService;

    @Transactional
    public PostLikeResponse toggleLike(Long actorId, Long postId) {
        User user = access.findUser(actorId);
        access.ensurePostExists(postId);
        if (!relations.lockPost(postId)) throw access.postNotFound();
        boolean inserted = reactionInserts.likeIfAbsent(PostLike.create(user.getId(), postId));
        if (!inserted) {
            relations.removeLike(user.getId(), postId);
            counters.decrementLikes(postId);
            return PostLikeResponse.of(postId, false, likesCount(postId));
        }
        access.ensurePostVisible(postId, user.getId());
        counters.incrementLikes(postId);
        Long recipient = postQueries.authorId(postId);
        notificationService.create(recipient, user.getId(), user.getNickname(), NotificationType.POST_LIKE, postId, null);
        return PostLikeResponse.of(postId, true, likesCount(postId));
    }

    @Transactional
    public PostResponse vote(Long actorId, Long postId, Long optionId) {
        User user = access.findUser(actorId);
        access.ensurePostVisible(postId, user.getId());
        if (!relations.lockPost(postId)) throw access.postNotFound();
        Long pollId = relations.pollId(postId).orElseThrow(() -> new IllegalArgumentException("Poll not found."));
        if (!relations.optionBelongsToPoll(pollId, optionId)) throw new IllegalArgumentException("Poll option not found.");
        boolean inserted = reactionInserts.voteIfAbsent(PostPollVote.create(pollId, user.getId(), optionId));
        if (inserted) {
            counters.incrementVotes(optionId);
            Long recipient = postQueries.authorId(postId);
            notificationService.create(recipient, user.getId(), user.getNickname(), NotificationType.POLL_VOTE, postId, null);
        } else {
            PostPollVote vote = relations.findVote(pollId, user.getId()).orElseThrow();
            Long previousOptionId = vote.getOptionId();
            if (vote.changeOption(optionId)) {
                relations.flush();
                counters.decrementVotes(previousOptionId);
                counters.incrementVotes(optionId);
            }
        }
        return postQueries.findCurrentPostResponse(postId, user.getId());
    }

    private int likesCount(Long postId) {
        return postQueries.likesCount(postId);
    }
}
