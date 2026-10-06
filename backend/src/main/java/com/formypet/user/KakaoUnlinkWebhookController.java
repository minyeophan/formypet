package com.formypet.user;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/webhooks/kakao/unlink")
@RequiredArgsConstructor
public class KakaoUnlinkWebhookController {
    private final KakaoUnlinkWebhookService service;

    @GetMapping
    public ResponseEntity<Void> get(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestParam("app_id") String appId,
            @RequestParam("user_id") String providerUserId,
            @RequestParam("referrer_type") String referrerType) {
        return respond(authorization, appId, providerUserId, referrerType);
    }

    @PostMapping
    public ResponseEntity<Void> post(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestParam("app_id") String appId,
            @RequestParam("user_id") String providerUserId,
            @RequestParam("referrer_type") String referrerType) {
        return respond(authorization, appId, providerUserId, referrerType);
    }

    private ResponseEntity<Void> respond(String authorization, String appId, String providerUserId, String referrerType) {
        return service.receive(authorization, appId, providerUserId, referrerType)
                ? ResponseEntity.ok().build()
                : ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
    }
}
