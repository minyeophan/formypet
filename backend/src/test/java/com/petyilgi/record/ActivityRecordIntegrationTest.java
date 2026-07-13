package com.petyilgi.record;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.petyilgi.auth.repository.RefreshTokenRepository;
import com.petyilgi.auth.repository.UserRepository;
import com.petyilgi.support.IntegrationTestSupport;
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
class ActivityRecordIntegrationTest extends IntegrationTestSupport {

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
    void createMealRecordSucceeds() throws Exception {
        String token = registerAndGetToken("meal@example.com", "meal");
        Long petId = createPet(token, "Mochi");

        mockMvc.perform(post(recordsUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "typeId", "meal",
                                "date", "2026-05-09",
                                "time", "08:30",
                                "note", "breakfast",
                                "detail", Map.of(
                                        "foodType", "dry",
                                        "servedAmount", 120.5,
                                        "consumedAmount", 100.0,
                                        "brand", "Acme"
                                )
                        ))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.id").isNumber())
                .andExpect(jsonPath("$.data.petId").value(petId))
                .andExpect(jsonPath("$.data.typeId").value("meal"))
                .andExpect(jsonPath("$.data.date").value("2026-05-09"))
                .andExpect(jsonPath("$.data.time").value("08:30:00"))
                .andExpect(jsonPath("$.data.detail.foodType").value("dry"))
                .andExpect(jsonPath("$.data.detail.servedAmount").value(120.5));
    }

    @Test
    void createRoutineRecordPersistsRoutineId() throws Exception {
        String token = registerAndGetToken("routine-record@example.com", "routine-record");
        Long petId = createPet(token, "Maro");
        Long routineId = createRoutine(token, petId, "Water", "water");

        mockMvc.perform(post(recordsUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "typeId", "water",
                                "date", "2026-05-09",
                                "time", "08:00",
                                "routineId", routineId,
                                "detail", Map.of("amount", 200)
                        ))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.routineId").value(routineId));

        mockMvc.perform(get(recordsUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .param("date", "2026-05-09"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].routineId").value(routineId));
    }

    @Test
    void createDiaryRecordSucceedsWithNoteOnlyDetail() throws Exception {
        String token = registerAndGetToken("diary-record@example.com", "diary-record");
        Long petId = createPet(token, "Maro");

        mockMvc.perform(post(recordsUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "typeId", "diary",
                                "date", "2026-05-09",
                                "time", "21:30",
                                "note", "오늘은 컨디션이 좋았다."
                        ))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.petId").value(petId))
                .andExpect(jsonPath("$.data.typeId").value("diary"))
                .andExpect(jsonPath("$.data.date").value("2026-05-09"))
                .andExpect(jsonPath("$.data.time").value("21:30:00"))
                .andExpect(jsonPath("$.data.note").value("오늘은 컨디션이 좋았다."))
                .andExpect(jsonPath("$.data.detail").isMap())
                .andExpect(jsonPath("$.data.detail").isEmpty());
    }

    @Test
    void createEtcRecordSucceedsWithNoteOnlyDetail() throws Exception {
        String token = registerAndGetToken("etc-record@example.com", "etc-record");
        Long petId = createPet(token, "Maro");

        MvcResult created = mockMvc.perform(post(recordsUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "typeId", "etc",
                                "date", "2026-05-09",
                                "time", "21:30",
                                "note", "free memo"
                        ))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.petId").value(petId))
                .andExpect(jsonPath("$.data.typeId").value("etc"))
                .andExpect(jsonPath("$.data.date").value("2026-05-09"))
                .andExpect(jsonPath("$.data.time").value("21:30:00"))
                .andExpect(jsonPath("$.data.note").value("free memo"))
                .andExpect(jsonPath("$.data.detail").isMap())
                .andExpect(jsonPath("$.data.detail").isEmpty())
                .andReturn();
        long recordId = objectMapper.readTree(created.getResponse().getContentAsString())
                .path("data")
                .path("id")
                .asLong();

        mockMvc.perform(get(recordsUrl(petId) + "/" + recordId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(recordId))
                .andExpect(jsonPath("$.data.typeId").value("etc"))
                .andExpect(jsonPath("$.data.note").value("free memo"))
                .andExpect(jsonPath("$.data.detail").isMap())
                .andExpect(jsonPath("$.data.detail").isEmpty());

        mockMvc.perform(delete(recordsUrl(petId) + "/" + recordId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        mockMvc.perform(get(recordsUrl(petId)).header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data", hasSize(0)));
    }

    @Test
    void getRecordReturnsSingleRecord() throws Exception {
        String token = registerAndGetToken("get-record@example.com", "get-record");
        Long petId = createPet(token, "Maro");
        Long recordId = createRecord(token, petId, "water", Map.of("amount", 200));

        mockMvc.perform(get(recordsUrl(petId) + "/" + recordId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(recordId))
                .andExpect(jsonPath("$.data.petId").value(petId))
                .andExpect(jsonPath("$.data.typeId").value("water"))
                .andExpect(jsonPath("$.data.detail.amount").value(200.0));
    }

    @Test
    void missingRecordReturnsNotFoundCode() throws Exception {
        String token = registerAndGetToken("missing-record@example.com", "missing-record");
        Long petId = createPet(token, "Maro");

        mockMvc.perform(get(recordsUrl(petId) + "/999999")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("ACTIVITY_RECORD_NOT_FOUND"));
    }

    @Test
    void getOtherUsersPetRecordReturns403() throws Exception {
        String ownerToken = registerAndGetToken("record-detail-owner@example.com", "owner");
        String otherToken = registerAndGetToken("record-detail-other@example.com", "other");
        Long petId = createPet(ownerToken, "OwnerPet");
        Long recordId = createRecord(ownerToken, petId, "water", Map.of("amount", 200));

        mockMvc.perform(get(recordsUrl(petId) + "/" + recordId)
                        .header("Authorization", "Bearer " + otherToken))
                .andExpect(status().isForbidden());
    }

    @Test
    void createRecordWithUnknownRoutineReturns400() throws Exception {
        String token = registerAndGetToken("unknown-routine-record@example.com", "unknown-routine");
        Long petId = createPet(token, "Maro");

        mockMvc.perform(post(recordsUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "typeId", "water",
                                "date", "2026-05-09",
                                "routineId", 999999,
                                "detail", Map.of("amount", 200)
                        ))))
                .andExpect(status().isBadRequest());
    }

    @Test
    void createRecordWithOtherPetsRoutineReturns403() throws Exception {
        String token = registerAndGetToken("other-pet-routine-record@example.com", "other-pet-routine");
        Long petId = createPet(token, "Maro");
        Long otherPetId = createPet(token, "Bori");
        Long otherRoutineId = createRoutine(token, otherPetId, "Other water", "water");

        mockMvc.perform(post(recordsUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "typeId", "water",
                                "date", "2026-05-09",
                                "routineId", otherRoutineId,
                                "detail", Map.of("amount", 200)
                        ))))
                .andExpect(status().isForbidden());
    }

    @Test
    void updateRecordRoutineIdRequiresSamePetRoutine() throws Exception {
        String token = registerAndGetToken("update-routine-record@example.com", "update-routine");
        Long petId = createPet(token, "Maro");
        Long otherPetId = createPet(token, "Bori");
        Long recordId = createRecord(token, petId, "water", Map.of("amount", 200));
        Long otherRoutineId = createRoutine(token, otherPetId, "Other water", "water");

        mockMvc.perform(put(recordsUrl(petId) + "/" + recordId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("routineId", otherRoutineId))))
                .andExpect(status().isForbidden());
    }

    @Test
    void updateRecordCanAttachSamePetRoutine() throws Exception {
        String token = registerAndGetToken("attach-routine-record@example.com", "attach-routine");
        Long petId = createPet(token, "Maro");
        Long recordId = createRecord(token, petId, "water", Map.of("amount", 200));
        Long routineId = createRoutine(token, petId, "Water", "water");

        mockMvc.perform(put(recordsUrl(petId) + "/" + recordId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("routineId", routineId))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.routineId").value(routineId));
    }

    @Test
    void createAllSupportedRecordTypesSucceeds() throws Exception {
        String token = registerAndGetToken("all-types@example.com", "types");
        Long petId = createPet(token, "Coco");

        createRecord(token, petId, "water", Map.of("amount", 250));
        createRecord(token, petId, "medicine", Map.of("medicineName", "heart pill", "dosage", "1 tablet"));
        createRecord(token, petId, "poop", Map.of("poopShape", "normal", "poopColor", "brown", "poopAmount", "normal"));
        createRecord(token, petId, "walk", Map.of(
                "distance", 1.2,
                "duration", 30,
                "startLng", 127.0276,
                "startLat", 37.4979,
                "endLng", 127.0300,
                "endLat", 37.5000
        ));
        createRecord(token, petId, "weight", Map.of("weight", 5.25));
        createRecord(token, petId, "vet", Map.of(
                "vetClinicName", "Town Vet",
                "clinicLng", 127.0276,
                "clinicLat", 37.4979,
                "vetVisitReason", "checkup",
                "vetCost", 30000
        ));
        createRecord(token, petId, "diary", Map.of());
        createRecord(token, petId, "etc", Map.of());

        mockMvc.perform(get(recordsUrl(petId)).header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data", hasSize(8)));
    }

    @Test
    void createDeprecatedRecordTypesReturnsInvalidInput() throws Exception {
        String token = registerAndGetToken("deprecated-create@example.com", "deprecated-create");
        Long petId = createPet(token, "Coco");

        for (String typeId : List.of("play", "sleep", "checkup")) {
            mockMvc.perform(post(recordsUrl(petId))
                            .header("Authorization", "Bearer " + token)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(Map.of(
                                    "typeId", typeId,
                                    "date", "2026-05-09"
                            ))))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.errorCode").value("INVALID_INPUT"));
        }
    }

    @Test
    void filterByDeprecatedRecordTypesReturnsInvalidInput() throws Exception {
        String token = registerAndGetToken("deprecated-filter@example.com", "deprecated-filter");
        Long petId = createPet(token, "Coco");

        for (String typeId : List.of("play", "sleep", "checkup")) {
            mockMvc.perform(get(recordsUrl(petId))
                            .header("Authorization", "Bearer " + token)
                            .param("typeId", typeId))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.errorCode").value("INVALID_INPUT"));
        }
    }

    @Test
    void filterRecordsByDateAndTypeReturnsCorrectSubset() throws Exception {
        String token = registerAndGetToken("filter@example.com", "filter");
        Long petId = createPet(token, "Dubu");

        createRecord(token, petId, "meal", "2026-05-09", Map.of("foodType", "dry"));
        createRecord(token, petId, "meal", "2026-05-10", Map.of("foodType", "wet"));
        createRecord(token, petId, "water", "2026-05-09", Map.of("amount", 180));

        mockMvc.perform(get(recordsUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .param("date", "2026-05-09")
                        .param("typeId", "meal"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data", hasSize(1)))
                .andExpect(jsonPath("$.data[0].typeId").value("meal"))
                .andExpect(jsonPath("$.data[0].date").value("2026-05-09"));
    }

    @Test
    void updateRecordOnlyChangesSpecifiedFields() throws Exception {
        String token = registerAndGetToken("update-record@example.com", "update");
        Long petId = createPet(token, "Bori");
        Long recordId = createRecord(token, petId, "weight", Map.of("weight", 4.8));

        mockMvc.perform(put(recordsUrl(petId) + "/" + recordId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "note", "after dinner",
                                "detail", Map.of("weight", 4.9)
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.typeId").value("weight"))
                .andExpect(jsonPath("$.data.note").value("after dinner"))
                .andExpect(jsonPath("$.data.detail.weight").value(4.9));
    }

    @Test
    void deleteRecordRemovesItFromList() throws Exception {
        String token = registerAndGetToken("delete-record@example.com", "delete");
        Long petId = createPet(token, "Nabi");
        Long recordId = createRecord(token, petId, "water", Map.of("amount", 200));

        mockMvc.perform(delete(recordsUrl(petId) + "/" + recordId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        mockMvc.perform(get(recordsUrl(petId)).header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data", hasSize(0)));
    }

    @Test
    void accessOtherUsersPetRecordsReturns403() throws Exception {
        String tokenA = registerAndGetToken("owner-record@example.com", "owner");
        String tokenB = registerAndGetToken("other-record@example.com", "other");
        Long petId = createPet(tokenA, "OwnerPet");

        mockMvc.perform(get(recordsUrl(petId)).header("Authorization", "Bearer " + tokenB))
                .andExpect(status().isForbidden());
    }

    private Long createRecord(String token, Long petId, String typeId, Map<String, Object> detail) throws Exception {
        return createRecord(token, petId, typeId, "2026-05-09", detail);
    }

    private Long createRecord(String token, Long petId, String typeId, String date, Map<String, Object> detail) throws Exception {
        MvcResult result = mockMvc.perform(post(recordsUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "typeId", typeId,
                                "date", date,
                                "time", "09:00",
                                "detail", detail
                        ))))
                .andExpect(status().isCreated())
                .andReturn();
        return readId(result);
    }

    private Long createRoutine(String token, Long petId, String label, String typeId) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/v1/pets/" + petId + "/routines")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "label", label,
                                "typeId", typeId,
                                "repeatType", "daily",
                                "startDate", "2026-05-09",
                                "times", java.util.List.of("08:00")
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

    private String recordsUrl(Long petId) {
        return "/api/v1/pets/" + petId + "/records";
    }
}
