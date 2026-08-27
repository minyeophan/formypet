package com.petyilgi.notification;
import com.petyilgi.common.response.ApiResponse; import com.petyilgi.notification.dto.*; import io.swagger.v3.oas.annotations.Operation; import io.swagger.v3.oas.annotations.tags.Tag; import jakarta.validation.Valid; import lombok.RequiredArgsConstructor; import org.springframework.security.core.annotation.AuthenticationPrincipal; import org.springframework.web.bind.annotation.*;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.Parameter;
@RestController @RequestMapping("/api/v1/notifications") @RequiredArgsConstructor
@Tag(name="Notifications", description="알림 및 예약 알림 설정 API")
@SecurityRequirement(name="bearerAuth")
public class NotificationController { private final NotificationService service;
 @Operation(summary="내 예약 알림 설정 조회")
 @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode="200", description="설정 조회 성공")
 @GetMapping("/settings") public ApiResponse<NotificationSettingsResponse> settings(@AuthenticationPrincipal String e){return ApiResponse.of(service.getSettings(e));}
 @Operation(summary="Update current user's scheduled notification setting")
 @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode="200", description="설정 변경 성공")
 @PatchMapping("/settings") public ApiResponse<NotificationSettingsResponse> updateSettings(@AuthenticationPrincipal String e,@Valid @RequestBody NotificationSettingsRequest request){return ApiResponse.of(service.updateSettings(e,request));}
 @Operation(summary="알림 목록 조회", description="최근 30일 알림을 cursor 기반으로 조회합니다. limit은 1~50입니다.")
 @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode="200", description="알림 목록 조회 성공")
 @GetMapping public ApiResponse<NotificationFeedResponse> list(@AuthenticationPrincipal String e,@Parameter(description="다음 페이지 cursor", required=false) @RequestParam(required=false)String cursor,@Parameter(description="페이지 크기 (1~50)", example="20") @RequestParam(defaultValue="20")int limit){return ApiResponse.of(service.list(e,cursor,limit));}
 @Operation(summary="알림 읽음 처리")
 @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode="200", description="읽음 처리 성공")
 @PatchMapping("/{id}/read") public ApiResponse<Void> read(@AuthenticationPrincipal String e,@PathVariable Long id){service.read(e,id);return ApiResponse.empty();}
 @Operation(summary="알림 전체 읽음 처리")
 @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode="200", description="전체 읽음 처리 성공")
 @PostMapping("/read-all") public ApiResponse<Void> readAll(@AuthenticationPrincipal String e){service.readAll(e);return ApiResponse.empty();}
}
