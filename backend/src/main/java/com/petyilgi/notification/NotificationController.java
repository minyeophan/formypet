package com.petyilgi.notification;
import com.petyilgi.common.response.ApiResponse; import com.petyilgi.notification.dto.*; import lombok.RequiredArgsConstructor; import org.springframework.http.*; import org.springframework.security.core.annotation.AuthenticationPrincipal; import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/v1/notifications") @RequiredArgsConstructor
public class NotificationController { private final NotificationService service;
 @GetMapping public ApiResponse<NotificationFeedResponse> list(@AuthenticationPrincipal String e,@RequestParam(required=false)String cursor,@RequestParam(defaultValue="20")int limit){return ApiResponse.of(service.list(e,cursor,limit));}
 @PatchMapping("/{id}/read") public ApiResponse<Void> read(@AuthenticationPrincipal String e,@PathVariable Long id){service.read(e,id);return ApiResponse.empty();}
 @PostMapping("/read-all") public ApiResponse<Void> readAll(@AuthenticationPrincipal String e){service.readAll(e);return ApiResponse.empty();}
}
