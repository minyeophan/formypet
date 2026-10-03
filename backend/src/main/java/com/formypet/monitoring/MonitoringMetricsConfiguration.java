package com.formypet.monitoring;

import io.micrometer.common.KeyValue;
import io.micrometer.common.KeyValues;
import io.micrometer.core.instrument.config.MeterFilter;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.server.observation.DefaultServerRequestObservationConvention;
import org.springframework.http.server.observation.ServerRequestObservationContext;
import org.springframework.http.server.observation.ServerRequestObservationConvention;

@Configuration(proxyBeanMethods = false)
@ConditionalOnProperty(name = "app.monitoring.enabled", havingValue = "true")
public class MonitoringMetricsConfiguration {
    @Bean
    ServerRequestObservationConvention monitoringRequestConvention() {
        return new DefaultServerRequestObservationConvention() {
            @Override
            public KeyValues getLowCardinalityKeyValues(ServerRequestObservationContext context) {
                String path = context.getCarrier().getRequestURI();
                String uri = context.getPathPattern();
                if (internal(path)) {
                    uri = "INTERNAL";
                } else if (uri == null || uri.isBlank()) {
                    int status = context.getResponse() == null ? 0 : context.getResponse().getStatus();
                    uri = status == 401 || status == 403 ? "AUTHENTICATION" : "UNMATCHED";
                }
                return super.getLowCardinalityKeyValues(context).and(KeyValue.of("uri", uri));
            }

            @Override
            public KeyValues getHighCardinalityKeyValues(ServerRequestObservationContext context) {
                // Do not retain the default full URL (which may contain personal query parameters).
                return KeyValues.empty();
            }
        };
    }

    @Bean
    MeterFilter excludeInternalHttpMetrics() {
        return MeterFilter.deny(id -> id.getName().startsWith("http.server.requests")
                && "INTERNAL".equals(id.getTag("uri")));
    }

    private static boolean internal(String path) {
        return path.equals("/actuator") || path.startsWith("/actuator/")
                || path.equals("/api/v1/health") || path.equals("/swagger-ui.html")
                || path.startsWith("/swagger-ui/") || path.equals("/v3/api-docs")
                || path.startsWith("/v3/api-docs/");
    }
}
