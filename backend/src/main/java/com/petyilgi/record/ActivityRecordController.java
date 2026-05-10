package com.petyilgi.record;

import com.petyilgi.common.response.ApiResponse;
import com.petyilgi.record.dto.ActivityRecordCreateRequest;
import com.petyilgi.record.dto.ActivityRecordResponse;
import com.petyilgi.record.dto.ActivityRecordUpdateRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/v1/pets/{petId}/records")
@RequiredArgsConstructor
public class ActivityRecordController {

    private final ActivityRecordService activityRecordService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<ActivityRecordResponse> create(@AuthenticationPrincipal String email,
                                                      @PathVariable Long petId,
                                                      @Valid @RequestBody ActivityRecordCreateRequest request) {
        return ApiResponse.of(activityRecordService.create(email, petId, request));
    }

    @GetMapping
    public ApiResponse<List<ActivityRecordResponse>> list(@AuthenticationPrincipal String email,
                                                          @PathVariable Long petId,
                                                          @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
                                                          @RequestParam(required = false) String typeId,
                                                          @RequestParam(required = false) Integer limit) {
        return ApiResponse.of(activityRecordService.list(email, petId, date, typeId, limit));
    }

    @PutMapping("/{recordId}")
    public ApiResponse<ActivityRecordResponse> update(@AuthenticationPrincipal String email,
                                                      @PathVariable Long petId,
                                                      @PathVariable Long recordId,
                                                      @RequestBody ActivityRecordUpdateRequest request) {
        return ApiResponse.of(activityRecordService.update(email, petId, recordId, request));
    }

    @DeleteMapping("/{recordId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal String email,
                       @PathVariable Long petId,
                       @PathVariable Long recordId) {
        activityRecordService.delete(email, petId, recordId);
    }
}
