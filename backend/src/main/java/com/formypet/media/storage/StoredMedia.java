package com.formypet.media.storage;

public record StoredMedia(String storageKey, String contentType, long fileSize) {
}
