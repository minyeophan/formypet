package com.formypet.routine;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.formypet.auth.repository.RefreshTokenRepository;
import com.formypet.auth.repository.UserRepository;
import com.formypet.support.IntegrationTestSupport;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;

import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@AutoConfigureMockMvc
@Transactional
class RoutineIntegrationTest extends IntegrationTestSupport {

    @Autowired MockMvc mockMvc;
    @Autowired ObjectMapper objectMapper;
    @Autowired UserRepository userRepository;
    @Autowired RefreshTokenRepository refreshTokenRepository;

    private static final String AUTH_URL = "/api/v1/auth/register";
    private static final String PETS_URL = "/api/v1/pets";

    @BeforeEach
    void setUp() {
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void createDailyRoutineSucceeds() throws Exception {
        String token = registerAndGetToken("daily-routine@example.com", "daily");
        Long petId = createPet(token, "Mochi");

        mockMvc.perform(post(routinesUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "label", "Morning meal",
                                "typeId", "meal",
                                "repeatType", "daily",
                                "startDate", "2026-05-09",
                                "times", List.of("08:00", "20:00")
                        ))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.id").isNumber())
                .andExpect(jsonPath("$.data.petId").value(petId))
                .andExpect(jsonPath("$.data.label").value("Morning meal"))
                .andExpect(jsonPath("$.data.repeatType").value("daily"))
                .andExpect(jsonPath("$.data.times[0]").value("08:00"));
    }

    @Test
    void createAndUpdateRoutineTemplateSucceeds() throws Exception {
        String token = registerAndGetToken("template-routine@example.com", "template");
        Long petId = createPet(token, "Maro");

        MvcResult createResult = mockMvc.perform(post(routinesUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "label", "Morning meal",
                                "typeId", "meal",
                                "repeatType", "daily",
                                "startDate", "2026-05-09",
                                "times", List.of("08:00"),
                                "note", "half portion",
                                "detail", Map.of(
                                        "foodType", "dry",
                                        "servedAmount", 80
                                )
                        ))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.note").value("half portion"))
                .andExpect(jsonPath("$.data.detail.foodType").value("dry"))
                .andExpect(jsonPath("$.data.detail.servedAmount").value(80))
                .andReturn();

        Long routineId = readId(createResult);

        mockMvc.perform(put(routinesUrl(petId) + "/" + routineId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "note", "full portion",
                                "detail", Map.of("servedAmount", 120)
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.note").value("full portion"))
                .andExpect(jsonPath("$.data.detail.servedAmount").value(120));

        mockMvc.perform(get(routinesUrl(petId)).header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].note").value("full portion"))
                .andExpect(jsonPath("$.data[0].detail.servedAmount").value(120));
    }

    @Test
    void createWeeklyRoutineWithDaysSucceeds() throws Exception {
        String token = registerAndGetToken("weekly-routine@example.com", "weekly");
        Long petId = createPet(token, "Coco");

        mockMvc.perform(post(routinesUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "label", "Medicine",
                                "typeId", "medicine",
                                "repeatType", "weekly",
                                "days", List.of(1, 3, 5),
                                "startDate", "2026-05-09",
                                "times", List.of("09:00")
                        ))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.days[0]").value(1))
                .andExpect(jsonPath("$.data.days[2]").value(5));
    }

    @Test
    void createRoutineWithUnknownActivityTypeReturnsInvalidInput() throws Exception {
        String token = registerAndGetToken("unknown-routine-type@example.com", "unknown-routine-type");
        Long petId = createPet(token, "Maro");

        mockMvc.perform(post(routinesUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "label", "Unknown",
                                "typeId", "unsupported-type",
                                "repeatType", "daily",
                                "startDate", "2026-05-09"
                        ))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("INVALID_INPUT"));
    }

    @Test
    void updateRoutineWithUnknownActivityTypeReturnsInvalidInput() throws Exception {
        String token = registerAndGetToken("update-unknown-routine-type@example.com", "update-unknown-routine-type");
        Long petId = createPet(token, "Maro");
        Long routineId = createRoutine(token, petId, "Meal", "meal");

        mockMvc.perform(put(routinesUrl(petId) + "/" + routineId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("typeId", "unsupported-type"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("INVALID_INPUT"));
    }

    @Test
    void createRoutineRejectsInvalidRepeatRules() throws Exception {
        String token = registerAndGetToken("invalid-repeat-routine@example.com", "invalid-repeat");
        Long petId = createPet(token, "Maro");

        mockMvc.perform(post(routinesUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "label": "Weekly",
                                  "typeId": "meal",
                                  "repeatType": "weekly",
                                  "days": [],
                                  "startDate": "2026-05-09"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("INVALID_INPUT"));
    }

    @Test
    void createRoutineRejectsInvalidTimesFormat() throws Exception {
        String token = registerAndGetToken("invalid-routine-times@example.com", "invalid-times");
        Long petId = createPet(token, "Maro");

        mockMvc.perform(post(routinesUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "label", "Meal",
                                "typeId", "meal",
                                "repeatType", "daily",
                                "startDate", "2026-05-09",
                                "times", List.of("25:00")
                        ))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("INVALID_INPUT"));
    }

    @Test
    void updateRoutineRejectsInvalidTimesFormat() throws Exception {
        String token = registerAndGetToken("update-invalid-routine-times@example.com", "update-invalid-times");
        Long petId = createPet(token, "Maro");
        Long routineId = createRoutine(token, petId, "Meal", "meal");

        mockMvc.perform(put(routinesUrl(petId) + "/" + routineId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("times", List.of("08:70")))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("INVALID_INPUT"));
    }

    @Test
    void createRoutineRejectsLabelLongerThanThirtyCharacters() throws Exception {
        String token = registerAndGetToken("long-routine-label@example.com", "long-label");
        Long petId = createPet(token, "Maro");

        mockMvc.perform(post(routinesUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "label", "a".repeat(31),
                                "typeId", "meal",
                                "repeatType", "daily",
                                "startDate", "2026-05-09"
                        ))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("INVALID_INPUT"));
    }

    @Test
    void updateRoutineRejectsLabelLongerThanThirtyCharacters() throws Exception {
        String token = registerAndGetToken("update-long-routine-label@example.com", "update-long-label");
        Long petId = createPet(token, "Maro");
        Long routineId = createRoutine(token, petId, "Meal", "meal");

        mockMvc.perform(put(routinesUrl(petId) + "/" + routineId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("label", "a".repeat(31)))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("INVALID_INPUT"));
    }

    @Test
    void markCompletionChangesStatus() throws Exception {
        String token = registerAndGetToken("completion-routine@example.com", "completion");
        Long petId = createPet(token, "Dubu");
        Long routineId = createRoutine(token, petId, "Water", "water");

        mockMvc.perform(patch(routinesUrl(petId) + "/" + routineId + "/completions/2026-05-09")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("status", "COMPLETED"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("COMPLETED"))
                .andExpect(jsonPath("$.data.scheduledDate").value("2026-05-09"));
    }

    @Test
    void todayCompletionRateCalculatesCorrectly() throws Exception {
        String token = registerAndGetToken("today-routine@example.com", "today");
        Long petId = createPet(token, "Bori");
        Long mealId = createRoutine(token, petId, "Meal", "meal");
        createRoutine(token, petId, "Walk", "walk");

        mockMvc.perform(patch(routinesUrl(petId) + "/" + mealId + "/completions/2026-05-09")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("status", "COMPLETED"))))
                .andExpect(status().isOk());

        mockMvc.perform(get(routinesUrl(petId) + "/today")
                        .header("Authorization", "Bearer " + token)
                        .param("date", "2026-05-09"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.routines", hasSize(2)))
                .andExpect(jsonPath("$.data.summary.total").value(2))
                .andExpect(jsonPath("$.data.summary.done").value(1))
                .andExpect(jsonPath("$.data.summary.rate").value(50.0));
    }

    @Test
    void deleteRoutineSucceeds() throws Exception {
        String token = registerAndGetToken("delete-routine@example.com", "delete");
        Long petId = createPet(token, "Nabi");
        Long routineId = createRoutine(token, petId, "Weight", "weight");

        mockMvc.perform(delete(routinesUrl(petId) + "/" + routineId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        mockMvc.perform(get(routinesUrl(petId)).header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data", hasSize(0)));
    }

    private Long createRoutine(String token, Long petId, String label, String typeId) throws Exception {
        MvcResult result = mockMvc.perform(post(routinesUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "label", label,
                                "typeId", typeId,
                                "repeatType", "daily",
                                "startDate", "2026-05-09",
                                "times", List.of("08:00")
                        ))))
                .andExpect(status().isCreated())
                .andReturn();
        return readId(result);
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

    private Long readId(MvcResult result) throws Exception {
        var data = (Map<?, ?>) objectMapper.readValue(result.getResponse().getContentAsString(), Map.class).get("data");
        return ((Number) data.get("id")).longValue();
    }

    private String routinesUrl(Long petId) {
        return "/api/v1/pets/" + petId + "/routines";
    }
}
