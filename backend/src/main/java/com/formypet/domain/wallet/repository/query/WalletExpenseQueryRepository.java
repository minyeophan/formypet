package com.formypet.domain.wallet.repository.query;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.formypet.global.exception.InvalidInputException;
import com.formypet.domain.wallet.dto.response.WalletExpenseCategorySummary;
import com.formypet.domain.wallet.dto.response.WalletExpenseListResponse;
import com.formypet.domain.wallet.dto.response.WalletExpenseResponse;
import com.formypet.domain.wallet.dto.response.WalletExpenseSummaryResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;

import java.sql.Time;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.Base64;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;


@org.springframework.stereotype.Repository
@RequiredArgsConstructor
public class WalletExpenseQueryRepository {
    private static final String DEFAULT_CURRENCY = "KRW";
    private static final int DEFAULT_LIMIT = 20;
    private static final int MAX_LIMIT = 50;
    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;

    public WalletExpenseListResponse list(Long petId, String cursor, Integer limit,
                                          LocalDate from, LocalDate to, String category) {

        int normalizedLimit = normalizeLimit(limit);
        validateDateRange(from, to);
        String normalizedCategory = normalizeOptionalCategory(category);
        Cursor decodedCursor = decodeCursor(cursor);

        List<Object> params = new ArrayList<>();
        params.add(petId);
        StringBuilder sql = new StringBuilder("""
                SELECT id, pet_id, expense_date, expense_time, amount, currency, category, item_name, note
                FROM wallet_expenses
                WHERE pet_id = ?
                """);
        appendFilters(sql, params, from, to, normalizedCategory);
        appendCursor(sql, params, decodedCursor);
        sql.append("""
                ORDER BY expense_date DESC, expense_time IS NULL ASC, expense_time DESC, id DESC
                LIMIT ?
                """);
        params.add(normalizedLimit + 1);

        List<WalletExpenseResponse> rows = jdbcTemplate.query(sql.toString(), (rs, rowNum) -> new WalletExpenseResponse(
                rs.getLong("id"),
                rs.getLong("pet_id"),
                rs.getObject("expense_date", LocalDate.class),
                normalizeTime(rs.getObject("expense_time")),
                rs.getLong("amount"),
                rs.getString("currency"),
                rs.getString("category"),
                WalletExpenseResponse.categoryLabel(rs.getString("category")),
                rs.getString("item_name"),
                rs.getString("note")
        ), params.toArray());

        boolean hasMore = rows.size() > normalizedLimit;
        List<WalletExpenseResponse> items = hasMore ? rows.subList(0, normalizedLimit) : rows;
        String nextCursor = hasMore ? encodeCursor(items.getLast()) : null;
        return new WalletExpenseListResponse(List.copyOf(items), nextCursor, hasMore);
    }

    public WalletExpenseSummaryResponse summary(Long petId, LocalDate from, LocalDate to, String category) {

        validateDateRange(from, to);
        String normalizedCategory = normalizeOptionalCategory(category);

        List<Object> params = new ArrayList<>();
        params.add(petId);
        StringBuilder where = new StringBuilder(" WHERE pet_id = ?");
        appendFilters(where, params, from, to, normalizedCategory);

        Map<String, Object> total = jdbcTemplate.queryForMap("""
                SELECT COALESCE(SUM(amount), 0) AS total_amount, COUNT(*) AS total_count
                FROM wallet_expenses
                """ + where, params.toArray());
        String categorySummarySql = """
                SELECT category, COALESCE(SUM(amount), 0) AS amount, COUNT(*) AS count
                FROM wallet_expenses
                """ + where
                + " GROUP BY category"
                + " ORDER BY amount DESC, category ASC";

        List<WalletExpenseCategorySummary> categories = jdbcTemplate.query(
                categorySummarySql,
                (rs, rowNum) -> new WalletExpenseCategorySummary(
                rs.getString("category"),
                WalletExpenseResponse.categoryLabel(rs.getString("category")),
                rs.getLong("amount"),
                rs.getLong("count")
        ), params.toArray());

        return new WalletExpenseSummaryResponse(
                ((Number) total.get("total_amount")).longValue(),
                ((Number) total.get("total_count")).longValue(),
                DEFAULT_CURRENCY,
                from,
                to,
                categories
        );
    }

    private void appendFilters(StringBuilder sql, List<Object> params, LocalDate from, LocalDate to, String category) {
        if (from != null) {
            sql.append(" AND expense_date >= ?");
            params.add(from);
        }
        if (to != null) {
            sql.append(" AND expense_date <= ?");
            params.add(to);
        }
        if (category != null) {
            sql.append(" AND category = ?");
            params.add(category);
        }
    }

    private void appendCursor(StringBuilder sql, List<Object> params, Cursor cursor) {
        if (cursor == null) {
            return;
        }
        sql.append(" AND (expense_date < ? OR (expense_date = ? AND ");
        params.add(cursor.expenseDate());
        params.add(cursor.expenseDate());
        if (cursor.expenseTime() == null) {
            sql.append("expense_time IS NULL AND id < ?))");
            params.add(cursor.id());
            return;
        }
        sql.append("(expense_time IS NULL OR expense_time < ? OR (expense_time = ? AND id < ?))))");
        params.add(cursor.expenseTime());
        params.add(cursor.expenseTime());
        params.add(cursor.id());
    }

    private Cursor decodeCursor(String cursor) {
        if (cursor == null || cursor.isBlank()) {
            return null;
        }
        try {
            byte[] decoded = Base64.getUrlDecoder().decode(cursor);
            Map<String, Object> payload = objectMapper.readValue(decoded, new TypeReference<>() {});
            LocalDate expenseDate = LocalDate.parse(Objects.toString(payload.get("expenseDate")));
            Object timeValue = payload.get("expenseTime");
            LocalTime expenseTime = timeValue == null ? null : LocalTime.parse(timeValue.toString());
            Long id = Long.valueOf(Objects.toString(payload.get("id")));
            return new Cursor(expenseDate, expenseTime, id);
        } catch (Exception ex) {
            throw new InvalidInputException("Invalid cursor.", "INVALID_CURSOR");
        }
    }

    private String encodeCursor(WalletExpenseResponse response) {
        try {
            Map<String, Object> payload = new HashMap<>();
            payload.put("expenseDate", response.expenseDate().toString());
            payload.put("expenseTime", response.expenseTime() == null ? null : response.expenseTime().toString());
            payload.put("id", response.id());
            byte[] json = objectMapper.writeValueAsBytes(payload);
            return Base64.getUrlEncoder().withoutPadding().encodeToString(json);
        } catch (Exception ex) {
            throw new InvalidInputException("Invalid cursor.", "INVALID_CURSOR");
        }
    }

    private int normalizeLimit(Integer limit) {
        if (limit == null) {
            return DEFAULT_LIMIT;
        }
        if (limit < 1 || limit > MAX_LIMIT) {
            throw InvalidInputException.invalidInput();
        }
        return limit;
    }

    private void validateDateRange(LocalDate from, LocalDate to) {
        if (from != null && to != null && from.isAfter(to)) {
            throw new InvalidInputException("Invalid date range.", "INVALID_DATE_RANGE");
        }
    }

    private String normalizeCategory(String category) {
        return com.formypet.domain.wallet.entity.WalletExpense.normalizeCategory(category);
    }

    private String normalizeOptionalCategory(String category) {
        if (category == null || category.isBlank()) {
            return null;
        }
        return normalizeCategory(category);
    }



    private LocalTime normalizeTime(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof LocalTime localTime) {
            return localTime;
        }
        if (value instanceof Time time) {
            return time.toLocalTime();
        }
        return LocalTime.parse(value.toString());
    }
    private record Cursor(LocalDate expenseDate, LocalTime expenseTime, Long id) {} 
}
