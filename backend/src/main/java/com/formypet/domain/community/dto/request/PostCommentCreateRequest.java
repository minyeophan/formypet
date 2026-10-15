package com.formypet.domain.community.dto.request;

public record PostCommentCreateRequest(String content, Long parentCommentId) {
}
