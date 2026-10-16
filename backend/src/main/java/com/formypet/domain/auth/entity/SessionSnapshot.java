package com.formypet.domain.auth.entity;

/** Authentication state read independently of managed User entities. */
public record SessionSnapshot(long id, String email, String passwordHash, String source, long version) {}
