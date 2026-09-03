package com.formypet.record;

import com.formypet.common.response.ApiResponse;
import com.formypet.record.dto.ActivityRecordCreateRequest;
import com.formypet.record.dto.ActivityRecordResponse;
import com.formypet.record.dto.ActivityRecordUpdateRequest;
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
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Schema;

@RestController
@RequestMapping("/api/v1/pets/{petId}/records")
@RequiredArgsConstructor
@Tag(name = "Activity Records", description = "활동 기록 API")
@SecurityRequirement(name = "bearerAuth")
public class ActivityRecordController {

    private final ActivityRecordService activityRecordService;

    @PostMapping
    @Operation(summary = "활동 기록 생성")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "201", description = "기록 생성 성공")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<ActivityRecordResponse> create(@AuthenticationPrincipal String email,
                                                      @PathVariable Long petId,
                                                      @Valid @RequestBody ActivityRecordCreateRequest request) {
        return ApiResponse.of(activityRecordService.create(email, petId, request));
    }

    @GetMapping
    @Operation(summary = "활동 기록 목록 조회", description = "limit은 1~100 범위입니다.")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "기록 목록 조회 성공")
    public ApiResponse<List<ActivityRecordResponse>> list(@AuthenticationPrincipal String email,
                                                          @PathVariable Long petId,
                                                          @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
                                                          @RequestParam(required = false) String typeId,
                                                          @Parameter(description = "조회할 최대 기록 수", required = false, example = "50", schema = @Schema(minimum = "1", maximum = "100")) @RequestParam(required = false) Integer limit) {
        return ApiResponse.of(activityRecordService.list(email, petId, date, typeId, limit));
    }

    @GetMapping("/{recordId}")
    @Operation(summary = "활동 기록 상세 조회")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "기록 조회 성공")
    public ApiResponse<ActivityRecordResponse> get(@AuthenticationPrincipal String email,
                                                   @PathVariable Long petId,
                                                   @PathVariable Long recordId) {
        return ApiResponse.of(activityRecordService.get(email, petId, recordId));
    }

    @PutMapping("/{recordId}")
    @Operation(summary = "활동 기록 수정")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "기록 수정 성공")
    public ApiResponse<ActivityRecordResponse> update(@AuthenticationPrincipal String email,
                                                      @PathVariable Long petId,
                                                      @PathVariable Long recordId,
                                                      @RequestBody ActivityRecordUpdateRequest request) {
        return ApiResponse.of(activityRecordService.update(email, petId, recordId, request));
    }

    @DeleteMapping("/{recordId}")
    @Operation(summary = "활동 기록 삭제")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "204", description = "기록 삭제 성공")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal String email,
                       @PathVariable Long petId,
                       @PathVariable Long recordId) {
        activityRecordService.delete(email, petId, recordId);
    }
}
