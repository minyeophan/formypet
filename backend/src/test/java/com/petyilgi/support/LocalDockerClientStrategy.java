package com.petyilgi.support;

import com.github.dockerjava.api.DockerClient;
import com.github.dockerjava.core.DefaultDockerClientConfig;
import com.github.dockerjava.core.DockerClientImpl;
import com.github.dockerjava.httpclient5.ApacheDockerHttpClient;
import org.testcontainers.dockerclient.DockerClientProviderStrategy;
import org.testcontainers.dockerclient.TransportConfig;

import java.net.URI;

/**
 * Docker Desktop 4.40+ on Windows: named pipe/TCP proxy returns Status 400 for API 1.32 default.
 * This strategy forces API 1.47 over tcp://127.0.0.1:2375 (requires Docker Desktop TCP enabled).
 */
public class LocalDockerClientStrategy extends DockerClientProviderStrategy {

    private static final String DOCKER_HOST = "tcp://127.0.0.1:2375";
    private static final String API_VERSION = "1.47";

    @Override
    public TransportConfig getTransportConfig() {
        return TransportConfig.builder()
                .dockerHost(URI.create(DOCKER_HOST))
                .build();
    }

    @Override
    public DockerClient getDockerClient() {
        DefaultDockerClientConfig config = DefaultDockerClientConfig.createDefaultConfigBuilder()
                .withDockerHost(DOCKER_HOST)
                .withApiVersion(API_VERSION)
                .build();

        ApacheDockerHttpClient httpClient = new ApacheDockerHttpClient.Builder()
                .dockerHost(config.getDockerHost())
                .sslConfig(config.getSSLConfig())
                .build();

        return DockerClientImpl.getInstance(config, httpClient);
    }

    @Override
    public String getDescription() {
        return "Local TCP docker client (API " + API_VERSION + ") for Docker Desktop on Windows";
    }

    @Override
    protected boolean isApplicable() {
        return true;
    }
}
