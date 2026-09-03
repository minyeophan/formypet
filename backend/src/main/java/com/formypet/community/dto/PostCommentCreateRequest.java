package com.formypet.community.dto;

public record PostCommentCreateRequest(String content, Long parentCommentId) {
}
