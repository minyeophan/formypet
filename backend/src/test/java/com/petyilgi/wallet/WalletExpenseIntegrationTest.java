package com.petyilgi.wallet;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.petyilgi.auth.repository.RefreshTokenRepository;
import com.petyilgi.auth.repository.UserRepository;
import com.petyilgi.support.IntegrationTestSupport;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.annotation.Transactional;

import java.util.Map;

import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.blankOrNullString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@Transactional
class WalletExpenseIntegrationTest extends IntegrationTestSupport {

    @Autowired MockMvc mockMvc;
    @Autowired ObjectMapper objectMapper;
    @Autowired UserRepository userRepository;
    @Autowired RefreshTokenRepository refreshTokenRepository;
    @Autowired JdbcTemplate jdbcTemplate;

    private static final String AUTH_URL = "/api/v1/auth/register";
    private static final String PETS_URL = "/api/v1/pets";

    @BeforeEach
    void setUp() {
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void createExpenseSucceeds() throws Exception {
        String token = registerAndGetToken("wallet-create@example.com", "wallet-create");
        Long petId = createPet(token, "Mochi");

        mockMvc.perform(post(expensesUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "expenseDate", "2026-06-12",
                                "expenseTime", "14:30",
                                "amount", 35000,
                                "currency", "KRW",
                                "category", "hospital",
                                "itemName", "regular checkup",
                                "note", "vaccination included"
                        ))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.id").isNumber())
                .andExpect(jsonPath("$.data.petId").value(petId))
                .andExpect(jsonPath("$.data.expenseDate").value("2026-06-12"))
                .andExpect(jsonPath("$.data.expenseTime").value("14:30:00"))
                .andExpect(jsonPath("$.data.amount").value(35000))
                .andExpect(jsonPath("$.data.currency").value("KRW"))
                .andExpect(jsonPath("$.data.category").value("hospital"))
                .andExpect(jsonPath("$.data.categoryLabel").value("\uBCD1\uC6D0"))
                .andExpect(jsonPath("$.data.itemName").value("regular checkup"))
                .andExpect(jsonPath("$.data.note").value("vaccination included"))
                .andExpect(jsonPath("$.data.createdAt").doesNotExist())
                .andExpect(jsonPath("$.data.updatedAt").doesNotExist());
    }

    @Test
    void createExpenseAllowsNullItemName() throws Exception {
        String token = registerAndGetToken("wallet-null@example.com", "wallet-null");
        Long petId = createPet(token, "Mochi");

        mockMvc.perform(post(expensesUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "expenseDate": "2026-06-12",
                                  "amount": 12000,
                                  "category": "food",
                                  "itemName": "",
                                  "note": null
                                }
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.currency").value("KRW"))
                .andExpect(jsonPath("$.data.expenseTime").doesNotExist())
                .andExpect(jsonPath("$.data.itemName").doesNotExist())
                .andExpect(jsonPath("$.data.note").doesNotExist());
    }

    @Test
    void updateExpenseClearsNullableFields() throws Exception {
        String token = registerAndGetToken("wallet-update@example.com", "wallet-update");
        Long petId = createPet(token, "Mochi");
        Long expenseId = createExpense(token, petId, "2026-06-12", "14:30", 35000, "hospital", "checkup", "memo");

        mockMvc.perform(put(expensesUrl(petId) + "/" + expenseId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "expenseDate": "2026-06-13",
                                  "expenseTime": null,
                                  "amount": 42000,
                                  "currency": "KRW",
                                  "category": "medicine",
                                  "itemName": null,
                                  "note": ""
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(expenseId))
                .andExpect(jsonPath("$.data.expenseDate").value("2026-06-13"))
                .andExpect(jsonPath("$.data.expenseTime").doesNotExist())
                .andExpect(jsonPath("$.data.itemName").doesNotExist())
                .andExpect(jsonPath("$.data.note").doesNotExist());
    }

    @Test
    void deleteExpenseReturnsNoContentAndRemovesFromList() throws Exception {
        String token = registerAndGetToken("wallet-delete@example.com", "wallet-delete");
        Long petId = createPet(token, "Mochi");
        Long expenseId = createExpense(token, petId, "2026-06-12", "14:30", 35000, "hospital", "checkup", "memo");

        mockMvc.perform(delete(expensesUrl(petId) + "/" + expenseId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        mockMvc.perform(get(expensesUrl(petId))
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(0)))
                .andExpect(jsonPath("$.data.nextCursor").doesNotExist())
                .andExpect(jsonPath("$.data.hasMore").value(false));
    }

    @Test
    void listExpensesUsesCursorWithoutDuplicates() throws Exception {
        String token = registerAndGetToken("wallet-cursor@example.com", "wallet-cursor");
        Long petId = createPet(token, "Mochi");
        Long olderId = createExpense(token, petId, "2026-06-11", null, 1000, "food", "older", null);
        Long firstId = createExpense(token, petId, "2026-06-12", "09:00", 2000, "snack", "first", null);
        Long newestId = createExpense(token, petId, "2026-06-12", "14:30", 3000, "hospital", "newest", null);

        MvcResult firstPage = mockMvc.perform(get(expensesUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .param("limit", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(2)))
                .andExpect(jsonPath("$.data.items[0].id").value(newestId))
                .andExpect(jsonPath("$.data.items[1].id").value(firstId))
                .andExpect(jsonPath("$.data.nextCursor", not(blankOrNullString())))
                .andExpect(jsonPath("$.data.hasMore").value(true))
                .andReturn();
        String cursor = objectMapper.readTree(firstPage.getResponse().getContentAsString())
                .path("data")
                .path("nextCursor")
                .asText();

        mockMvc.perform(get(expensesUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .param("limit", "2")
                        .param("cursor", cursor))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(1)))
                .andExpect(jsonPath("$.data.items[0].id").value(olderId))
                .andExpect(jsonPath("$.data.hasMore").value(false));
    }

    @Test
    void listExpensesFiltersByDateAndCategory() throws Exception {
        String token = registerAndGetToken("wallet-filter@example.com", "wallet-filter");
        Long petId = createPet(token, "Mochi");
        createExpense(token, petId, "2026-06-10", "09:00", 1000, "food", "old food", null);
        Long expectedId = createExpense(token, petId, "2026-06-12", "09:00", 2000, "food", "food", null);
        createExpense(token, petId, "2026-06-12", "10:00", 3000, "hospital", "hospital", null);

        mockMvc.perform(get(expensesUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .param("from", "2026-06-12")
                        .param("to", "2026-06-12")
                        .param("category", "food"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items", hasSize(1)))
                .andExpect(jsonPath("$.data.items[0].id").value(expectedId));
    }

    @Test
    void summaryReturnsTotalAndCategoryBreakdown() throws Exception {
        String token = registerAndGetToken("wallet-summary@example.com", "wallet-summary");
        Long petId = createPet(token, "Mochi");
        createExpense(token, petId, "2026-06-12", "09:00", 2000, "food", "food", null);
        createExpense(token, petId, "2026-06-12", "10:00", 3000, "food", "food2", null);
        createExpense(token, petId, "2026-06-13", "10:00", 7000, "hospital", "hospital", null);

        mockMvc.perform(get(expensesUrl(petId) + "/summary")
                        .header("Authorization", "Bearer " + token)
                        .param("from", "2026-06-12")
                        .param("to", "2026-06-12"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalAmount").value(5000))
                .andExpect(jsonPath("$.data.count").value(2))
                .andExpect(jsonPath("$.data.currency").value("KRW"))
                .andExpect(jsonPath("$.data.from").value("2026-06-12"))
                .andExpect(jsonPath("$.data.to").value("2026-06-12"))
                .andExpect(jsonPath("$.data.categories", hasSize(1)))
                .andExpect(jsonPath("$.data.categories[0].category").value("food"))
                .andExpect(jsonPath("$.data.categories[0].amount").value(5000));
    }

    @Test
    void summaryWithoutFiltersReturnsTotalAndCategoryBreakdown() throws Exception {
        String token = registerAndGetToken(
                "wallet-unfiltered-summary@example.com",
                "wallet-unfiltered-summary"
        );
        Long petId = createPet(token, "Mochi");
        createExpense(token, petId, "2026-06-12", "09:00",
                2000, "food", "food", null);
        createExpense(token, petId, "2026-06-13", "10:00",
                7000, "hospital", "hospital", null);

        mockMvc.perform(get(expensesUrl(petId) + "/summary")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalAmount").value(9000))
                .andExpect(jsonPath("$.data.count").value(2))
                .andExpect(jsonPath("$.data.currency").value("KRW"))
                .andExpect(jsonPath("$.data.from").doesNotExist())
                .andExpect(jsonPath("$.data.to").doesNotExist())
                .andExpect(jsonPath("$.data.categories", hasSize(2)))
                .andExpect(jsonPath("$.data.categories[0].category")
                        .value("hospital"))
                .andExpect(jsonPath("$.data.categories[0].amount").value(7000))
                .andExpect(jsonPath("$.data.categories[1].category")
                        .value("food"))
                .andExpect(jsonPath("$.data.categories[1].amount").value(2000));
    }

    @Test
    void summaryReturnsEmptySummary() throws Exception {
        String token = registerAndGetToken("wallet-empty-summary@example.com", "wallet-empty-summary");
        Long petId = createPet(token, "Mochi");

        mockMvc.perform(get(expensesUrl(petId) + "/summary")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalAmount").value(0))
                .andExpect(jsonPath("$.data.count").value(0))
                .andExpect(jsonPath("$.data.currency").value("KRW"))
                .andExpect(jsonPath("$.data.from").doesNotExist())
                .andExpect(jsonPath("$.data.to").doesNotExist())
                .andExpect(jsonPath("$.data.categories", hasSize(0)));
    }

    @Test
    void petAndExpenseErrorsReturnErrorCodes() throws Exception {
        String token = registerAndGetToken("wallet-errors@example.com", "wallet-errors");
        String otherToken = registerAndGetToken("wallet-errors-other@example.com", "wallet-errors-other");
        Long petId = createPet(token, "Mochi");
        Long otherPetId = createPet(otherToken, "Other");
        Long expenseId = createExpense(token, petId, "2026-06-12", "14:30", 35000, "hospital", "checkup", null);

        mockMvc.perform(get(expensesUrl(999999L))
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("PET_NOT_FOUND"));

        mockMvc.perform(get(expensesUrl(otherPetId))
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("PET_FORBIDDEN"));

        jdbcTemplate.update("UPDATE pets SET is_deleted = true WHERE id = ?", petId);
        mockMvc.perform(get(expensesUrl(petId))
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("PET_NOT_FOUND_OR_DELETED"));
        jdbcTemplate.update("UPDATE pets SET is_deleted = false WHERE id = ?", petId);

        mockMvc.perform(get(expensesUrl(otherPetId) + "/" + expenseId)
                        .header("Authorization", "Bearer " + otherToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("WALLET_EXPENSE_NOT_FOUND"));
    }

    @Test
    void invalidInputsReturnSpecificErrorCodes() throws Exception {
        String token = registerAndGetToken("wallet-invalid@example.com", "wallet-invalid");
        Long petId = createPet(token, "Mochi");

        mockMvc.perform(get(expensesUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .param("cursor", "not-base64"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("INVALID_CURSOR"));

        mockMvc.perform(get(expensesUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .param("from", "2026-06-13")
                        .param("to", "2026-06-12"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("INVALID_DATE_RANGE"));

        mockMvc.perform(get(expensesUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .param("limit", "0"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("INVALID_INPUT"));

        mockMvc.perform(post(expensesUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("INVALID_INPUT"));

        mockMvc.perform(post(expensesUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "expenseDate": "2026-06-12",
                                  "amount": 0,
                                  "category": ""
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.fieldErrors").isMap());

        mockMvc.perform(post(expensesUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "expenseDate": "2026-06-12",
                                  "amount": 1000,
                                  "currency": "USD",
                                  "category": "food"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("INVALID_INPUT"));
    }

    @Test
    void unauthenticatedRequestReturnsUnauthorizedCode() throws Exception {
        mockMvc.perform(get(expensesUrl(1L)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("UNAUTHORIZED"));
    }

    private String registerAndGetToken(String email, String nickname) throws Exception {
        MvcResult result = mockMvc.perform(post(AUTH_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "email", email,
                                "password", "Password1!",
                                "nickname", nickname
                        ))))
                .andExpect(status().isCreated())
                .andReturn();
        var data = (Map<?, ?>) objectMapper.readValue(result.getResponse().getContentAsString(), Map.class).get("data");
        return (String) data.get("accessToken");
    }

    private Long createPet(String token, String name) throws Exception {
        MvcResult result = mockMvc.perform(post(PETS_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "name", name,
                                "species", "dog",
                                "birthDate", "2022-03-15"
                        ))))
                .andExpect(status().isCreated())
                .andReturn();
        return readId(result);
    }

    private Long createExpense(String token, Long petId, String date, String time, long amount,
                               String category, String itemName, String note) throws Exception {
        String body = objectMapper.writeValueAsString(new java.util.LinkedHashMap<String, Object>() {{
            put("expenseDate", date);
            put("expenseTime", time);
            put("amount", amount);
            put("currency", "KRW");
            put("category", category);
            put("itemName", itemName);
            put("note", note);
        }});
        MvcResult result = mockMvc.perform(post(expensesUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isCreated())
                .andReturn();
        return readId(result);
    }

    private Long readId(MvcResult result) throws Exception {
        var data = (Map<?, ?>) objectMapper.readValue(result.getResponse().getContentAsString(), Map.class).get("data");
        return ((Number) data.get("id")).longValue();
    }

    private String expensesUrl(Long petId) {
        return "/api/v1/pets/" + petId + "/wallet/expenses";
    }
}
