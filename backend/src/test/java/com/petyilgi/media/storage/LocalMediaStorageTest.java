package com.petyilgi.media.storage;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertThrows;

class LocalMediaStorageTest {

    @Test
    void loadRejectsNullContentTypeBeforeReadingFile() {
        LocalMediaStorage storage = new LocalMediaStorage("build/test-media-storage");

        assertThrows(
                IllegalArgumentException.class,
                () -> storage.load("missing.bin", null)
        );
    }
}
