package com.formypet.domain.wallet.dto.response;

import java.util.List;

public record WalletExpenseListResponse(
        List<WalletExpenseResponse> items,
        String nextCursor,
        boolean hasMore
) {
}
