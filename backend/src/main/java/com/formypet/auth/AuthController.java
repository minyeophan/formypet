package com.formypet.auth;

import com.formypet.auth.dto.LoginRequest;
import com.formypet.auth.dto.KakaoLoginRequest;
import com.formypet.auth.dto.RefreshRequest;
import com.formypet.auth.dto.RegisterRequest;
import com.formypet.auth.dto.TokenResponse;
import com.formypet.common.response.ApiResponse;
import com.formypet.common.ratelimit.ClientAddressResolver;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import io.swagger.v3.oas.annotations.tags.Tag;
import io.swagger.v3.oas.annotations.Operation;

@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
@Tag(name = "Authentication", description = "회원가입 및 인증 토큰 API")
public class AuthController {

    private final AuthService authService;
    private final KakaoSignupIntents signupIntents;
    private final ClientAddressResolver clientAddressResolver;
    public record CancelSignup(@jakarta.validation.constraints.NotBlank @jakarta.validation.constraints.Size(max=200) String signupToken) {}
    @PostMapping("/kakao/signup-cancellation")
    public ApiResponse<KakaoSignupIntents.Cancellation> cancelSignup(@Valid @RequestBody CancelSignup body) {
        return ApiResponse.of(signupIntents.cancel(body.signupToken()));
    }

    @PostMapping("/register")
    @Operation(summary = "회원가입", description = "새 계정을 생성하고 access/refresh token을 반환합니다.")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "201", description = "회원가입 성공")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<TokenResponse> register(@Valid @RequestBody RegisterRequest request,
                                               jakarta.servlet.http.HttpServletRequest servletRequest) {
        String clientAddress = clientAddressResolver.resolve(servletRequest);
        authService.admitRegistration(clientAddress);
        return ApiResponse.of(authService.register(request));
    }

    @PostMapping("/login")
    @Operation(summary = "로그인")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "로그인 성공")
    public ApiResponse<TokenResponse> login(@Valid @RequestBody LoginRequest request,
                                            jakarta.servlet.http.HttpServletRequest servletRequest) {
        String clientAddress = clientAddressResolver.resolve(servletRequest);
        authService.admitLogin(request.email(), clientAddress);
        return ApiResponse.of(authService.login(request));
    }

    @PostMapping("/kakao")
    @Operation(summary = "카카오 로그인")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "카카오 로그인 성공")
    public ApiResponse<TokenResponse> kakaoLogin(@Valid @RequestBody KakaoLoginRequest request,
            jakarta.servlet.http.HttpServletRequest servletRequest,
            @RequestHeader(value="X-Policy-Flow", required=false) String policyFlow) {
        String clientAddress = clientAddressResolver.resolve(servletRequest);
        authService.admitKakaoLogin(clientAddress);
        var response = authService.kakaoLogin(request);
        if (response.signupRequired() && !"1".equals(policyFlow)) {
            // The committed intent expires into cleanup even for an old client.
            throw com.formypet.policy.PolicyCatalog.error(HttpStatus.UPGRADE_REQUIRED,
                    "APP_UPDATE_REQUIRED", "가입 동의를 지원하는 최신 앱으로 업데이트해 주세요.");
        }
        return ApiResponse.of(response);
    }

    @PostMapping("/refresh")
    @Operation(summary = "access token 갱신")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "토큰 갱신 성공")
    public ApiResponse<TokenResponse> refresh(@Valid @RequestBody RefreshRequest request) {
        return ApiResponse.of(authService.refresh(request.refreshToken()));
    }

    @PostMapping("/logout")
    @Operation(summary = "로그아웃")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "204", description = "로그아웃 성공")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logout(@Valid @RequestBody RefreshRequest request) {
        authService.logout(request.refreshToken());
    }
}
