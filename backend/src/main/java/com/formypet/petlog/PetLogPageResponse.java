package com.formypet.petlog;

import java.util.List;

public record PetLogPageResponse(List<PetLogResponse> items, String nextCursor,
                                 List<Integer> years, boolean hasAny) {}
