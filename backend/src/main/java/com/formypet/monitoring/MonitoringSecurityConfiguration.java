package com.formypet.monitoring;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.actuate.autoconfigure.security.servlet.EndpointRequest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.ProviderManager;
import org.springframework.security.authentication.dao.DaoAuthenticationProvider;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.www.BasicAuthenticationEntryPoint;
import org.springframework.security.web.util.matcher.AntPathRequestMatcher;
import org.springframework.security.web.util.matcher.OrRequestMatcher;
import org.springframework.util.StringUtils;

@Configuration(proxyBeanMethods = false)
public class MonitoringSecurityConfiguration {
    @Bean
    @Order(0)
    SecurityFilterChain monitoringSecurity(HttpSecurity http, PasswordEncoder encoder,
            @Value("${app.monitoring.enabled:false}") boolean enabled,
            @Value("${app.monitoring.username:}") String username,
            @Value("${app.monitoring.password:}") String password) throws Exception {
        // Also intercept actual endpoints when external configuration relocates Actuator.
        // Only the documented default GET path below is allowed; relocated endpoints fail closed.
        http.securityMatcher(new OrRequestMatcher(EndpointRequest.toAnyEndpoint(),
                        new AntPathRequestMatcher("/actuator"), new AntPathRequestMatcher("/actuator/**")))
                .csrf(AbstractHttpConfigurer::disable)
                .requestCache(AbstractHttpConfigurer::disable)
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS));
        if (enabled) {
            if (!StringUtils.hasText(username) || !StringUtils.hasText(password)) {
                throw new IllegalStateException("Monitoring requires MONITORING_USERNAME and MONITORING_PASSWORD");
            }
            var users = new InMemoryUserDetailsManager(User.withUsername(username)
                    .password(encoder.encode(password)).roles("MONITORING").build());
            var provider = new DaoAuthenticationProvider();
            provider.setUserDetailsService(users);
            provider.setPasswordEncoder(encoder);
            // No parent/global provider: these credentials must never authenticate app requests.
            http.authenticationManager(new ProviderManager(provider));
            var entryPoint = new BasicAuthenticationEntryPoint();
            entryPoint.setRealmName("formypet-metrics");
            entryPoint.afterPropertiesSet();
            http.httpBasic(basic -> basic.authenticationEntryPoint(entryPoint))
                    .exceptionHandling(errors -> errors.authenticationEntryPoint(entryPoint))
                    .authorizeHttpRequests(auth -> auth
                            .requestMatchers(HttpMethod.GET, "/actuator/prometheus").hasRole("MONITORING")
                            .anyRequest().denyAll());
        } else {
            http.authorizeHttpRequests(auth -> auth.anyRequest().denyAll())
                    .exceptionHandling(errors -> errors.authenticationEntryPoint((req, res, ex) -> res.setStatus(404)));
        }
        return http.build();
    }
}
