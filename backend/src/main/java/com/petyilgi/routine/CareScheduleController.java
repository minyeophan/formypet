package com.petyilgi.routine;

import com.petyilgi.common.response.ApiResponse;
import com.petyilgi.routine.dto.CareScheduleRequest;
import com.petyilgi.routine.dto.CareScheduleResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/pets/{petId}/care-schedules")
@RequiredArgsConstructor
public class CareScheduleController {

    private final CareScheduleService careScheduleService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<CareScheduleResponse> create(@AuthenticationPrincipal String email,
                                                    @PathVariable Long petId,
                                                    @Valid @RequestBody CareScheduleRequest request) {
        return ApiResponse.of(careScheduleService.create(email, petId, request));
    }

    @GetMapping
    public ApiResponse<List<CareScheduleResponse>> list(@AuthenticationPrincipal String email,
                                                        @PathVariable Long petId) {
        return ApiResponse.of(careScheduleService.list(email, petId));
    }

    @GetMapping("/{scheduleId}")
    public ApiResponse<CareScheduleResponse> get(@AuthenticationPrincipal String email,
                                                 @PathVariable Long petId,
                                                 @PathVariable Long scheduleId) {
        return ApiResponse.of(careScheduleService.get(email, petId, scheduleId));
    }

    @PutMapping("/{scheduleId}")
    public ApiResponse<CareScheduleResponse> update(@AuthenticationPrincipal String email,
                                                    @PathVariable Long petId,
                                                    @PathVariable Long scheduleId,
                                                    @Valid @RequestBody CareScheduleRequest request) {
        return ApiResponse.of(careScheduleService.update(email, petId, scheduleId, request));
    }

    @DeleteMapping("/{scheduleId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal String email,
                       @PathVariable Long petId,
                       @PathVariable Long scheduleId) {
        careScheduleService.delete(email, petId, scheduleId);
    }
}
