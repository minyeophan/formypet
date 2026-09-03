package com.formypet.routine;

import com.formypet.common.response.ApiResponse;
import com.formypet.routine.dto.CareScheduleRequest;
import com.formypet.routine.dto.CareScheduleResponse;
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
import io.swagger.v3.oas.annotations.tags.Tag;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;

@RestController
@RequestMapping("/api/v1/pets/{petId}/care-schedules")
@RequiredArgsConstructor
@Tag(name = "Care Schedules", description = "케어 일정 관리 API")
@SecurityRequirement(name = "bearerAuth")
public class CareScheduleController {

    private final CareScheduleService careScheduleService;

    @PostMapping
    @Operation(summary = "케어 일정 생성")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "201", description = "케어 일정 생성 성공")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<CareScheduleResponse> create(@AuthenticationPrincipal String email,
                                                    @PathVariable Long petId,
                                                    @Valid @RequestBody CareScheduleRequest request) {
        return ApiResponse.of(careScheduleService.create(email, petId, request));
    }

    @GetMapping
    @Operation(summary = "케어 일정 목록 조회")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "케어 일정 목록 조회 성공")
    public ApiResponse<List<CareScheduleResponse>> list(@AuthenticationPrincipal String email,
                                                        @PathVariable Long petId) {
        return ApiResponse.of(careScheduleService.list(email, petId));
    }

    @GetMapping("/{scheduleId}")
    @Operation(summary = "케어 일정 상세 조회")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "케어 일정 조회 성공")
    public ApiResponse<CareScheduleResponse> get(@AuthenticationPrincipal String email,
                                                 @PathVariable Long petId,
                                                 @PathVariable Long scheduleId) {
        return ApiResponse.of(careScheduleService.get(email, petId, scheduleId));
    }

    @PutMapping("/{scheduleId}")
    @Operation(summary = "케어 일정 수정")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "케어 일정 수정 성공")
    public ApiResponse<CareScheduleResponse> update(@AuthenticationPrincipal String email,
                                                    @PathVariable Long petId,
                                                    @PathVariable Long scheduleId,
                                                    @Valid @RequestBody CareScheduleRequest request) {
        return ApiResponse.of(careScheduleService.update(email, petId, scheduleId, request));
    }

    @DeleteMapping("/{scheduleId}")
    @Operation(summary = "케어 일정 삭제")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "204", description = "케어 일정 삭제 성공")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal String email,
                       @PathVariable Long petId,
                       @PathVariable Long scheduleId) {
        careScheduleService.delete(email, petId, scheduleId);
    }
}
