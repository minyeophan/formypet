package com.petyilgi.wallet;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.petyilgi.common.exception.ForbiddenException;
import com.petyilgi.common.exception.InvalidInputException;
import com.petyilgi.common.exception.NotFoundException;
import com.petyilgi.wallet.dto.WalletExpenseCategorySummary;
import com.petyilgi.wallet.dto.WalletExpenseCreateRequest;
import com.petyilgi.wallet.dto.WalletExpenseListResponse;
import com.petyilgi.wallet.dto.WalletExpenseResponse;
import com.petyilgi.wallet.dto.WalletExpenseSummaryResponse;
import com.petyilgi.wallet.dto.WalletExpenseUpdateRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.Statement;
import java.sql.Time;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.Base64;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class WalletExpenseService {

    private static final Set<String> CATEGORIES = Set.of(
            "food", "snack", "hospital", "medicine", "grooming", "supplies", "etc"
    );
    private static final String DEFAULT_CURRENCY = "KRW";
    private static final int DEFAULT_LIMIT = 20;
    private static final int MAX_LIMIT = 50;

    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;

    @Transactional
    public WalletExpenseResponse create(String email, Long petId, WalletExpenseCreateRequest request) {
        PetRow pet = findVisibleOwnedPet(email, petId);
        String currency = normalizeCurrency(request.currency());
        String category = normalizeCategory(request.category());
        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbcTemplate.update(connection -> {
            PreparedStatement ps = connection.prepareStatement("""
                    INSERT INTO wallet_expenses
                        (user_id, pet_id, expense_date, expense_time, amount, currency, category, item_name, note)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, Statement.RETURN_GENERATED_KEYS);
            ps.setLong(1, pet.userId());
            ps.setLong(2, pet.id());
            ps.setObject(3, request.expenseDate());
            ps.setObject(4, request.expenseTime());
            ps.setLong(5, request.amount());
            ps.setString(6, currency);
            ps.setString(7, category);
            ps.setString(8, normalizeNullableText(request.itemName()));
            ps.setString(9, normalizeNullableText(request.note()));
            return ps;
        }, keyHolder);
        Long expenseId = Objects.requireNonNull(keyHolder.getKey()).longValue();
        return findResponse(pet.id(), expenseId);
    }

    @Transactional(readOnly = true)
    public WalletExpenseListResponse list(String email, Long petId, String cursor, Integer limit,
                                          LocalDate from, LocalDate to, String category) {
        PetRow pet = findVisibleOwnedPet(email, petId);
        int normalizedLimit = normalizeLimit(limit);
        validateDateRange(from, to);
        String normalizedCategory = normalizeOptionalCategory(category);
        Cursor decodedCursor = decodeCursor(cursor);

        List<Object> params = new ArrayList<>();
        params.add(pet.id());
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
                categoryLabel(rs.getString("category")),
                rs.getString("item_name"),
                rs.getString("note")
        ), params.toArray());

        boolean hasMore = rows.size() > normalizedLimit;
        List<WalletExpenseResponse> items = hasMore ? rows.subList(0, normalizedLimit) : rows;
        String nextCursor = hasMore ? encodeCursor(items.getLast()) : null;
        return new WalletExpenseListResponse(List.copyOf(items), nextCursor, hasMore);
    }

    @Transactional(readOnly = true)
    public WalletExpenseSummaryResponse summary(String email, Long petId, LocalDate from, LocalDate to, String category) {
        PetRow pet = findVisibleOwnedPet(email, petId);
        validateDateRange(from, to);
        String normalizedCategory = normalizeOptionalCategory(category);

        List<Object> params = new ArrayList<>();
        params.add(pet.id());
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
                categoryLabel(rs.getString("category")),
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

    @Transactional(readOnly = true)
    public WalletExpenseResponse get(String email, Long petId, Long expenseId) {
        PetRow pet = findVisibleOwnedPet(email, petId);
        return findResponse(pet.id(), expenseId);
    }

    @Transactional
    public WalletExpenseResponse update(String email, Long petId, Long expenseId, WalletExpenseUpdateRequest request) {
        PetRow pet = findVisibleOwnedPet(email, petId);
        findResponse(pet.id(), expenseId);
        String currency = normalizeCurrency(request.currency());
        String category = normalizeCategory(request.category());
        jdbcTemplate.update("""
                UPDATE wallet_expenses
                SET expense_date = ?, expense_time = ?, amount = ?, currency = ?, category = ?, item_name = ?, note = ?
                WHERE id = ? AND pet_id = ?
                """,
                request.expenseDate(),
                request.expenseTime(),
                request.amount(),
                currency,
                category,
                normalizeNullableText(request.itemName()),
                normalizeNullableText(request.note()),
                expenseId,
                pet.id());
        return findResponse(pet.id(), expenseId);
    }

    @Transactional
    public void delete(String email, Long petId, Long expenseId) {
        PetRow pet = findVisibleOwnedPet(email, petId);
        findResponse(pet.id(), expenseId);
        jdbcTemplate.update("DELETE FROM wallet_expenses WHERE id = ? AND pet_id = ?", expenseId, pet.id());
    }

    private WalletExpenseResponse findResponse(Long petId, Long expenseId) {
        List<WalletExpenseResponse> rows = jdbcTemplate.query("""
                SELECT id, pet_id, expense_date, expense_time, amount, currency, category, item_name, note
                FROM wallet_expenses
                WHERE id = ? AND pet_id = ?
                """, (rs, rowNum) -> new WalletExpenseResponse(
                rs.getLong("id"),
                rs.getLong("pet_id"),
                rs.getObject("expense_date", LocalDate.class),
                normalizeTime(rs.getObject("expense_time")),
                rs.getLong("amount"),
                rs.getString("currency"),
                rs.getString("category"),
                categoryLabel(rs.getString("category")),
                rs.getString("item_name"),
                rs.getString("note")
        ), expenseId, petId);
        if (rows.isEmpty()) {
            throw new NotFoundException("Wallet expense not found.", "WALLET_EXPENSE_NOT_FOUND");
        }
        return rows.getFirst();
    }

    private PetRow findVisibleOwnedPet(String email, Long petId) {
        Long userId = findUserId(email);
        List<PetRow> rows = jdbcTemplate.query("""
                SELECT id, user_id, is_deleted
                FROM pets
                WHERE id = ?
                """, (rs, rowNum) -> new PetRow(
                rs.getLong("id"),
                rs.getLong("user_id"),
                rs.getBoolean("is_deleted")
        ), petId);
        if (rows.isEmpty()) {
            throw new NotFoundException("Pet not found.", "PET_NOT_FOUND");
        }
        PetRow pet = rows.getFirst();
        if (!pet.userId().equals(userId)) {
            throw new ForbiddenException("Forbidden pet.", "PET_FORBIDDEN");
        }
        if (pet.deleted()) {
            throw new NotFoundException("Pet not found or deleted.", "PET_NOT_FOUND_OR_DELETED");
        }
        return pet;
    }

    private Long findUserId(String email) {
        List<Long> ids = jdbcTemplate.queryForList("SELECT id FROM users WHERE email = ?", Long.class, email);
        if (ids.isEmpty()) {
            throw new InvalidInputException("User not found.", "INVALID_INPUT");
        }
        return ids.getFirst();
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

    private String normalizeCurrency(String currency) {
        String value = currency == null || currency.isBlank() ? DEFAULT_CURRENCY : currency.trim();
        if (!DEFAULT_CURRENCY.equals(value)) {
            throw InvalidInputException.invalidInput();
        }
        return value;
    }

    private String normalizeCategory(String category) {
        String value = category == null ? "" : category.trim();
        if (!CATEGORIES.contains(value)) {
            throw InvalidInputException.invalidInput();
        }
        return value;
    }

    private String normalizeOptionalCategory(String category) {
        if (category == null || category.isBlank()) {
            return null;
        }
        return normalizeCategory(category);
    }

    private String normalizeNullableText(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private String categoryLabel(String category) {
        return switch (category) {
            case "food" -> "\uC0AC\uB8CC";
            case "snack" -> "\uAC04\uC2DD";
            case "hospital" -> "\uBCD1\uC6D0";
            case "medicine" -> "\uC57D";
            case "grooming" -> "\uBBF8\uC6A9";
            case "supplies" -> "\uC6A9\uD488";
            case "etc" -> "\uAE30\uD0C0";
            default -> category;
        };
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

    private LocalDate normalizeDate(Object value) {
        if (value instanceof LocalDate localDate) {
            return localDate;
        }
        if (value instanceof Date date) {
            return date.toLocalDate();
        }
        return LocalDate.parse(value.toString());
    }

    private record PetRow(Long id, Long userId, boolean deleted) {
    }

    private record Cursor(LocalDate expenseDate, LocalTime expenseTime, Long id) {
    }
}
