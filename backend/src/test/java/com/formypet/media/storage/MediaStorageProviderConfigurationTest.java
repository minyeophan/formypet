package com.formypet.media.storage;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import static org.assertj.core.api.Assertions.assertThat;

class MediaStorageProviderConfigurationTest {

    private final ApplicationContextRunner context = new ApplicationContextRunner()
            .withUserConfiguration(LocalMediaStorage.class, R2MediaStorageConfiguration.class);

    @Test
    void localStorageIsTheDefaultProvider() {
        context.run(application -> {
            assertThat(application).hasSingleBean(MediaStorage.class);
            assertThat(application).hasBean("localMediaStorage");
        });
    }

    @Test
    void localProviderCanBeSelectedExplicitly() {
        context.withPropertyValues("app.media.storage.provider=local")
                .run(application -> {
                    assertThat(application).hasSingleBean(MediaStorage.class);
                    assertThat(application).hasBean("localMediaStorage");
                });
    }

    @Test
    void r2ProviderSelectsR2StorageAndConfiguresClientWithoutConnecting() {
        context.withPropertyValues(
                        "app.media.storage.provider=r2",
                        "r2.endpoint=https://account-id.r2.cloudflarestorage.com",
                        "r2.bucket=formypet-media-dev",
                        "r2.region=auto",
                        "r2.access-key-id=test-access-key",
                        "r2.secret-access-key=test-secret-key")
                .run(application -> {
                    assertThat(application).hasSingleBean(MediaStorage.class);
                    assertThat(application).hasBean("r2MediaStorage");
                    assertThat(application).hasBean("r2S3Client");
                    assertThat(application).doesNotHaveBean("localMediaStorage");
                });
    }
}
