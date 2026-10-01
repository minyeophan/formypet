package com.formypet.media.storage;

import org.springframework.lang.NonNull;

public record LoadedMedia(byte[] bytes, @NonNull String contentType) {
}
