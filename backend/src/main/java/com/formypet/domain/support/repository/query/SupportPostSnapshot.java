package com.formypet.domain.support.repository.query;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonPropertyOrder;

@JsonPropertyOrder({"user_id", "title", "content", "nickname"})
public record SupportPostSnapshot(@JsonProperty("user_id") long userId, String title, String content, String nickname) {}
