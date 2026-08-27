package com.petyilgi.notification;
import com.petyilgi.common.response.ApiResponse; import com.petyilgi.notification.dto.*; import io.swagger.v3.oas.annotations.Operation; import io.swagger.v3.oas.annotations.tags.Tag; import jakarta.validation.Valid; import lombok.RequiredArgsConstructor; import org.springframework.security.core.annotation.AuthenticationPrincipal; import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/v1/notifications") @RequiredArgsConstructor
@Tag(name="Notifications")
public class NotificationController { private final NotificationService service;
 @Operation(summary="Get current user's scheduled notification setting")
 @GetMapping("/settings") public ApiResponse<NotificationSettingsResponse> settings(@AuthenticationPrincipal String e){return ApiResponse.of(service.getSettings(e));}
 @Operation(summary="Update current user's scheduled notification setting")
 @PatchMapping("/settings") public ApiResponse<NotificationSettingsResponse> updateSettings(@AuthenticationPrincipal String e,@Valid @RequestBody NotificationSettingsRequest request){return ApiResponse.of(service.updateSettings(e,request));}
 @GetMapping public ApiResponse<NotificationFeedResponse> list(@AuthenticationPrincipal String e,@RequestParam(required=false)String cursor,@RequestParam(defaultValue="20")int limit){return ApiResponse.of(service.list(e,cursor,limit));}
 @PatchMapping("/{id}/read") public ApiResponse<Void> read(@AuthenticationPrincipal String e,@PathVariable Long id){service.read(e,id);return ApiResponse.empty();}
 @PostMapping("/read-all") public ApiResponse<Void> readAll(@AuthenticationPrincipal String e){service.readAll(e);return ApiResponse.empty();}
}
