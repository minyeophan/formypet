package com.petyilgi.pet;

import com.petyilgi.common.response.ApiResponse;
import com.petyilgi.pet.dto.PetCreateRequest;
import com.petyilgi.pet.dto.PetResponse;
import com.petyilgi.pet.dto.PetUpdateRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/pets")
@RequiredArgsConstructor
public class PetController {

    private final PetService petService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<PetResponse> create(@AuthenticationPrincipal String email,
                                           @Valid @RequestBody PetCreateRequest request) {
        return ApiResponse.of(petService.create(email, request));
    }

    @GetMapping
    public ApiResponse<List<PetResponse>> list(@AuthenticationPrincipal String email) {
        return ApiResponse.of(petService.list(email));
    }

    @PutMapping("/{id}")
    public ApiResponse<PetResponse> update(@AuthenticationPrincipal String email,
                                           @PathVariable Long id,
                                           @Valid @RequestBody PetUpdateRequest request) {
        return ApiResponse.of(petService.update(email, id, request));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal String email, @PathVariable Long id) {
        petService.delete(email, id);
    }
}
