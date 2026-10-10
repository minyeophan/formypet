package com.formypet.media.storage;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.web.multipart.MultipartFile;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class LocalMediaStorageFailureTest {
    @TempDir Path root;

    @Test void partialWriteCanBeRemovedUsingThePreallocatedKey() throws Exception {
        var storage = new LocalMediaStorage(root.toString());
        var file = mock(MultipartFile.class);
        doAnswer(call -> {
            Files.write(call.getArgument(0, Path.class), new byte[]{1, 2});
            throw new IOException("disk full after partial write");
        }).when(file).transferTo(any(Path.class));
        String key = MediaStorage.allocateKey(1L, "profile", "png");
        assertThatThrownBy(() -> storage.storeAt(key, file)).isInstanceOf(IOException.class);
        assertThat(root.resolve(key)).exists();
        storage.delete(key);
        assertThat(root.resolve(key)).doesNotExist();
        storage.delete(key);
    }
}
