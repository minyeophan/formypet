package com.petyilgi.routine;

import com.petyilgi.common.response.ApiResponse;
import com.petyilgi.routine.dto.*;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/v1/pets/{petId}/routines")
@RequiredArgsConstructor
public class RoutineController {

    private final RoutineService routineService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<RoutineResponse> create(@AuthenticationPrincipal String email,
                                               @PathVariable Long petId,
                                               @Valid @RequestBody RoutineCreateRequest request) {
        return ApiResponse.of(routineService.create(email, petId, request));
    }

    @GetMapping
    public ApiResponse<List<RoutineResponse>> list(@AuthenticationPrincipal String email,
                                                   @PathVariable Long petId) {
        return ApiResponse.of(routineService.list(email, petId));
    }

    @GetMapping("/today")
    public ApiResponse<TodayRoutineResponse> today(@AuthenticationPrincipal String email,
                                                   @PathVariable Long petId,
                                                   @RequestParam(required = false)
                                                   @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return ApiResponse.of(routineService.today(email, petId, date));
    }

    @PutMapping("/{routineId}")
    public ApiResponse<RoutineResponse> update(@AuthenticationPrincipal String email,
                                               @PathVariable Long petId,
                                               @PathVariable Long routineId,
                                               @RequestBody RoutineUpdateRequest request) {
        return ApiResponse.of(routineService.update(email, petId, routineId, request));
    }

    @PatchMapping("/{routineId}/completions/{date}")
    public ApiResponse<RoutineCompletionResponse> markCompletion(@AuthenticationPrincipal String email,
                                                                 @PathVariable Long petId,
                                                                 @PathVariable Long routineId,
                                                                 @PathVariable
                                                                 @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
                                                                 @Valid @RequestBody RoutineCompletionRequest request) {
        return ApiResponse.of(routineService.markCompletion(email, petId, routineId, date, request));
    }

    @DeleteMapping("/{routineId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal String email,
                       @PathVariable Long petId,
                       @PathVariable Long routineId) {
        routineService.delete(email, petId, routineId);
    }
}
