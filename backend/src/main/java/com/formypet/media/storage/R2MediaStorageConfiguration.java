package com.formypet.media.storage;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;

import java.net.URI;

@Configuration(proxyBeanMethods = false)
@ConditionalOnProperty(prefix = "app.media.storage", name = "provider", havingValue = "r2")
@EnableConfigurationProperties(R2StorageProperties.class)
public class R2MediaStorageConfiguration {

    @Bean(destroyMethod = "close")
    S3Client r2S3Client(R2StorageProperties properties) {
        var credentials = AwsBasicCredentials.create(properties.getAccessKeyId(), properties.getSecretAccessKey());
        return S3Client.builder()
                .endpointOverride(URI.create(properties.getEndpoint()))
                .region(Region.of(properties.getRegion()))
                .credentialsProvider(StaticCredentialsProvider.create(credentials))
                .serviceConfiguration(S3Configuration.builder()
                        .pathStyleAccessEnabled(true)
                        .chunkedEncodingEnabled(false)
                        .build())
                .build();
    }

    @Bean
    MediaStorage r2MediaStorage(S3Client r2S3Client, R2StorageProperties properties) {
        return new R2MediaStorage(r2S3Client, properties.getBucket());
    }
}
