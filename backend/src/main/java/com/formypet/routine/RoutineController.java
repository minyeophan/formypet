package com.formypet.routine;

import com.formypet.common.response.ApiResponse;
import com.formypet.routine.dto.*;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import io.swagger.v3.oas.annotations.tags.Tag;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;

@RestController
@RequestMapping("/api/v1/pets/{petId}/routines")
@RequiredArgsConstructor
@Tag(name = "Routines", description = "루틴 및 완료 기록 API")
@SecurityRequirement(name = "bearerAuth")
public class RoutineController {

    private final RoutineService routineService;

    @PostMapping
    @Operation(summary = "루틴 생성")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "201", description = "루틴 생성 성공")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<RoutineResponse> create(@AuthenticationPrincipal String email,
                                               @PathVariable Long petId,
                                               @Valid @RequestBody RoutineCreateRequest request) {
        return ApiResponse.of(routineService.create(email, petId, request));
    }

    @GetMapping
    @Operation(summary = "루틴 목록 조회")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "루틴 목록 조회 성공")
    public ApiResponse<List<RoutineResponse>> list(@AuthenticationPrincipal String email,
                                                   @PathVariable Long petId) {
        return ApiResponse.of(routineService.list(email, petId));
    }

    @GetMapping("/today")
    @Operation(summary = "오늘의 루틴 조회")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "오늘의 루틴 조회 성공")
    public ApiResponse<TodayRoutineResponse> today(@AuthenticationPrincipal String email,
                                                   @PathVariable Long petId,
                                                   @RequestParam(required = false)
                                                   @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return ApiResponse.of(routineService.today(email, petId, date));
    }

    @PutMapping("/{routineId}")
    @Operation(summary = "루틴 수정")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "루틴 수정 성공")
    public ApiResponse<RoutineResponse> update(@AuthenticationPrincipal String email,
                                               @PathVariable Long petId,
                                               @PathVariable Long routineId,
                                               @RequestBody RoutineUpdateRequest request) {
        return ApiResponse.of(routineService.update(email, petId, routineId, request));
    }

    @PatchMapping("/{routineId}/completions/{date}")
    @Operation(summary = "루틴 완료 상태 변경")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "완료 상태 변경 성공")
    public ApiResponse<RoutineCompletionResponse> markCompletion(@AuthenticationPrincipal String email,
                                                                 @PathVariable Long petId,
                                                                 @PathVariable Long routineId,
                                                                 @PathVariable
                                                                 @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
                                                                 @Valid @RequestBody RoutineCompletionRequest request) {
        return ApiResponse.of(routineService.markCompletion(email, petId, routineId, date, request));
    }

    @DeleteMapping("/{routineId}")
    @Operation(summary = "루틴 삭제")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "204", description = "루틴 삭제 성공")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal String email,
                       @PathVariable Long petId,
                       @PathVariable Long routineId) {
        routineService.delete(email, petId, routineId);
    }
}
