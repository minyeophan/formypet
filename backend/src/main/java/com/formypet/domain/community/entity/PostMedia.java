package com.formypet.domain.community.entity;

import jakarta.persistence.*;
import lombok.*;
import java.io.Serializable;

@Entity @Table(name = "post_media") @IdClass(PostMedia.Key.class)
@Getter @NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PostMedia {
    @Id @Column(name = "post_id")
    private Long postId;
    @Id @Column(name = "media_id")
    private Long mediaId;
    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    public static PostMedia create(Long postId, Long mediaId, int sortOrder) {
        var media = new PostMedia();
        media.postId = postId;
        media.mediaId = mediaId;
        media.sortOrder = sortOrder;
        return media;
    }

    @NoArgsConstructor @AllArgsConstructor @EqualsAndHashCode
    public static class Key implements Serializable {
        private Long postId;
        private Long mediaId;
    }
}
