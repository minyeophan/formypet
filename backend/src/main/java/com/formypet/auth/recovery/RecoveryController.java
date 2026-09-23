package com.formypet.auth.recovery;

import com.formypet.auth.validation.NewPassword;
import com.formypet.common.response.ApiResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import java.time.Instant;

@RestController
@RequestMapping("/api/v1/auth/password-reset")
@RequiredArgsConstructor
public class RecoveryController {
    private final RecoveryService service;
    public record Request(@NotBlank @Email @Size(max=254) String email){}
    public record Verify(@NotNull @Pattern(regexp="[A-Za-z0-9_-]{43}") String challengeId,
                         @NotNull @Pattern(regexp="[0-9]{6}") String code,
                         @NotNull @Pattern(regexp="[A-Za-z0-9_-]{16,64}") String requestId){}
    public record Confirm(@NotNull @Pattern(regexp="[A-Za-z0-9_-]{43}") String resetToken,
                          @NewPassword String newPassword,
                          @NotNull @Pattern(regexp="[A-Za-z0-9_-]{16,64}") String requestId){}
    public record Challenge(String challengeId,Instant expiresAt,Instant resendAvailableAt){}
    public record Verified(String resetToken,Instant expiresAt){}
    @PostMapping("/request") public ApiResponse<Challenge> request(@Valid @RequestBody Request body,HttpServletRequest request){
        return ApiResponse.of(service.request(body.email(),request.getRemoteAddr()));
    }
    @PostMapping("/verify") public ApiResponse<Verified> verify(@Valid @RequestBody Verify body,HttpServletRequest request){
        return ApiResponse.of(service.verify(body,request.getRemoteAddr()));
    }
    @PostMapping("/confirm") public ApiResponse<Void> confirm(@Valid @RequestBody Confirm body,HttpServletRequest request){
        service.confirm(body,request.getRemoteAddr());return ApiResponse.empty();
    }
}
