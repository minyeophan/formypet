package com.formypet.pet;

import com.formypet.common.response.ApiResponse;
import com.formypet.pet.dto.PetCreateRequest;
import com.formypet.pet.dto.PetResponse;
import com.formypet.pet.dto.PetUpdateRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import io.swagger.v3.oas.annotations.tags.Tag;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;

@RestController
@RequestMapping("/api/v1/pets")
@RequiredArgsConstructor
@Tag(name = "Pets", description = "반려동물 관리 API")
@SecurityRequirement(name = "bearerAuth")
public class PetController {

    private final PetService petService;

    @PostMapping
    @Operation(summary = "반려동물 등록")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "201", description = "등록 성공")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<PetResponse> create(@AuthenticationPrincipal(expression = "id") Long actorId,
                                           @Valid @RequestBody PetCreateRequest request) {
        return ApiResponse.of(petService.create(actorId, request));
    }

    @GetMapping
    @Operation(summary = "내 반려동물 목록 조회")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "조회 성공")
    public ApiResponse<List<PetResponse>> list(@AuthenticationPrincipal(expression = "id") Long actorId) {
        return ApiResponse.of(petService.list(actorId));
    }

    @PutMapping("/{id}")
    @Operation(summary = "반려동물 수정")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "수정 성공")
    public ApiResponse<PetResponse> update(@AuthenticationPrincipal(expression = "id") Long actorId,
                                           @PathVariable Long id,
                                           @Valid @RequestBody PetUpdateRequest request) {
        return ApiResponse.of(petService.update(actorId, id, request));
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "반려동물 삭제")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "204", description = "삭제 성공")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal(expression = "id") Long actorId, @PathVariable Long id) {
        petService.delete(actorId, id);
    }
}
