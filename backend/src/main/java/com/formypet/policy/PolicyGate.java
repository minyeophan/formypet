package com.formypet.policy;

import com.formypet.auth.AuthenticatedUser;
import jakarta.servlet.http.*;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.config.annotation.*;

@Configuration
@RequiredArgsConstructor
public class PolicyGate implements WebMvcConfigurer, HandlerInterceptor {
    private final PolicyConsentService policies;
    @Override public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(this).addPathPatterns("/api/v1/**");
    }
    @Override public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        String path = request.getRequestURI().substring(request.getContextPath().length());
        String method = request.getMethod();
        if (path.startsWith("/api/v1/auth/") || path.startsWith("/api/v1/public/")
                || path.equals("/api/v1/users/me/policy-status") || path.equals("/api/v1/users/me/policy-consents")
                || path.equals("/api/v1/users/me") && (method.equals("GET") || method.equals("DELETE"))
                || path.equals("/api/v1/inquiries") && method.equals("POST")
                || path.equals("/api/v1/notifications/device-tokens") && method.equals("DELETE")
                || path.equals("/api/v1/notifications/settings") && (method.equals("GET") || method.equals("PATCH"))) return true;
        var auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getPrincipal() instanceof AuthenticatedUser user) policies.requireAccepted(user.id());
        return true;
    }
}
