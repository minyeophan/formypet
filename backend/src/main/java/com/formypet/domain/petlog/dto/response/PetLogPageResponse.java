package com.formypet.domain.petlog.dto.response;

import com.formypet.domain.petlog.dto.response.PetLogResponse;

import java.util.List;

public record PetLogPageResponse(List<PetLogResponse> items, String nextCursor,
                                 List<Integer> years, boolean hasAny) {}
