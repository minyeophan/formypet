package com.petyilgi.wallet.dto;

import java.util.List;

public record WalletExpenseListResponse(
        List<WalletExpenseResponse> items,
        String nextCursor,
        boolean hasMore
) {
}
