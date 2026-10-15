package com.formypet.domain.community.repository;

import com.formypet.domain.community.entity.*;
import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
@RequiredArgsConstructor
public class PostRelationsRepository {
    private final EntityManager em;

    /** Serialize reactions on one post; locking reads also see the latest committed reaction. */
    public boolean lockPost(Long postId) {
        return !em.createQuery("select p from Post p where p.id = :id", Post.class)
                .setParameter("id", postId).setLockMode(LockModeType.PESSIMISTIC_WRITE).getResultList().isEmpty();
    }

    public void addMedia(PostMedia media) { em.persist(media); }
    public void addPoll(PostPoll poll) { em.persist(poll); }
    public void addOption(PostPollOption option) { em.persist(option); }
    public void removeLike(Long userId, Long postId) {
        em.createQuery("delete from PostLike l where l.userId = :userId and l.postId = :postId")
                .setParameter("userId", userId).setParameter("postId", postId).executeUpdate();
    }
    public void flush() { em.flush(); }

    public Optional<PostPollVote> findVote(Long pollId, Long userId) {
        return Optional.ofNullable(em.find(PostPollVote.class, new PostPollVote.Key(pollId, userId), LockModeType.PESSIMISTIC_WRITE));
    }

    public Optional<Long> pollId(Long postId) {
        return em.createQuery("select p.id from PostPoll p where p.postId = :postId", Long.class)
                .setParameter("postId", postId).getResultStream().findFirst();
    }

    public boolean optionBelongsToPoll(Long pollId, Long optionId) {
        return em.createQuery("select count(o) from PostPollOption o where o.pollId = :pollId and o.id = :id", Long.class)
                .setParameter("pollId", pollId).setParameter("id", optionId).getSingleResult() > 0;
    }

    public List<Long> mediaIds(Long postId) {
        return em.createQuery("select m.mediaId from PostMedia m where m.postId = :postId", Long.class)
                .setParameter("postId", postId).getResultList();
    }

    public boolean mediaHasReferences(Long mediaId) {
        return em.createQuery("select count(m) from PostMedia m where m.mediaId = :mediaId", Long.class)
                .setParameter("mediaId", mediaId).getSingleResult() > 0;
    }
}
