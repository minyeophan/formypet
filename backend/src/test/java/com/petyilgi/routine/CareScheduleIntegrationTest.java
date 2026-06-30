package com.petyilgi.routine;

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

import java.util.LinkedHashMap;
import java.util.Map;

import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@Transactional
class CareScheduleIntegrationTest extends IntegrationTestSupport {

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
    void createListGetUpdateAndDeleteScheduleSucceeds() throws Exception {
        String token = registerAndGetToken("care-schedule@example.com", "schedule");
        Long petId = createPet(token, "Mochi");

        MvcResult createResult = mockMvc.perform(post(schedulesUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(scheduleBody(
                                "hospital", "Regular checkup", "2026-07-01", "09:05",
                                "2026-07-01", "10:30", false, "Clinic", "Bring records", "1 hour before"))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.id").isNumber())
                .andExpect(jsonPath("$.data.petId").value(petId))
                .andExpect(jsonPath("$.data.categoryId").value("hospital"))
                .andExpect(jsonPath("$.data.title").value("Regular checkup"))
                .andExpect(jsonPath("$.data.startDate").value("2026-07-01"))
                .andExpect(jsonPath("$.data.startTime").value("09:05"))
                .andExpect(jsonPath("$.data.endDate").value("2026-07-01"))
                .andExpect(jsonPath("$.data.endTime").value("10:30"))
                .andExpect(jsonPath("$.data.allDay").value(false))
                .andExpect(jsonPath("$.data.place").value("Clinic"))
                .andExpect(jsonPath("$.data.memo").value("Bring records"))
                .andExpect(jsonPath("$.data.reminder").value("1 hour before"))
                .andExpect(jsonPath("$.data.createdAt").isString())
                .andReturn();
        Long scheduleId = readId(createResult);

        mockMvc.perform(get(schedulesUrl(petId)).header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data", hasSize(1)))
                .andExpect(jsonPath("$.data[0].id").value(scheduleId));

        mockMvc.perform(get(schedulesUrl(petId) + "/" + scheduleId).header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(scheduleId))
                .andExpect(jsonPath("$.data.startTime").value("09:05"));

        mockMvc.perform(put(schedulesUrl(petId) + "/" + scheduleId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(scheduleBody(
                                "grooming", "Haircut", "2026-07-02", null,
                                "2026-07-02", null, true, null, null, "none"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(scheduleId))
                .andExpect(jsonPath("$.data.categoryId").value("grooming"))
                .andExpect(jsonPath("$.data.startTime").doesNotExist())
                .andExpect(jsonPath("$.data.endTime").doesNotExist())
                .andExpect(jsonPath("$.data.allDay").value(true))
                .andExpect(jsonPath("$.data.place").doesNotExist())
                .andExpect(jsonPath("$.data.memo").doesNotExist());

        mockMvc.perform(delete(schedulesUrl(petId) + "/" + scheduleId).header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        mockMvc.perform(get(schedulesUrl(petId)).header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data", hasSize(0)));
    }

    @Test
    void invalidDateRangeReturnsSpecificErrorCode() throws Exception {
        String token = registerAndGetToken("care-invalid@example.com", "invalid");
        Long petId = createPet(token, "Mochi");

        mockMvc.perform(post(schedulesUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(scheduleBody(
                                "hospital", "Checkup", "2026-07-03", "10:00",
                                "2026-07-02", "11:00", false, null, null, "none"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("INVALID_DATE_RANGE"));
    }

    @Test
    void petAndScheduleErrorsReturnExpectedCodes() throws Exception {
        String token = registerAndGetToken("care-errors@example.com", "errors");
        String otherToken = registerAndGetToken("care-errors-other@example.com", "other");
        Long petId = createPet(token, "Mochi");
        Long otherPetId = createPet(otherToken, "Other");
        Long scheduleId = createSchedule(token, petId);

        mockMvc.perform(get(schedulesUrl(999999L)).header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("PET_NOT_FOUND"));

        mockMvc.perform(get(schedulesUrl(otherPetId)).header("Authorization", "Bearer " + token))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("PET_FORBIDDEN"));

        jdbcTemplate.update("UPDATE pets SET is_deleted = true WHERE id = ?", petId);
        mockMvc.perform(get(schedulesUrl(petId)).header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("PET_NOT_FOUND_OR_DELETED"));
        jdbcTemplate.update("UPDATE pets SET is_deleted = false WHERE id = ?", petId);

        mockMvc.perform(get(schedulesUrl(otherPetId) + "/" + scheduleId)
                        .header("Authorization", "Bearer " + otherToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("CARE_SCHEDULE_NOT_FOUND"));
    }

    private Long createSchedule(String token, Long petId) throws Exception {
        MvcResult result = mockMvc.perform(post(schedulesUrl(petId))
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(scheduleBody(
                                "hospital", "Checkup", "2026-07-01", "09:00",
                                "2026-07-01", "10:00", false, null, null, "none"))))
                .andExpect(status().isCreated())
                .andReturn();
        return readId(result);
    }

    private Map<String, Object> scheduleBody(String categoryId, String title, String startDate, String startTime,
                                             String endDate, String endTime, boolean allDay,
                                             String place, String memo, String reminder) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("categoryId", categoryId);
        body.put("title", title);
        body.put("startDate", startDate);
        body.put("startTime", startTime);
        body.put("endDate", endDate);
        body.put("endTime", endTime);
        body.put("allDay", allDay);
        body.put("place", place);
        body.put("memo", memo);
        body.put("reminder", reminder);
        return body;
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

    private String schedulesUrl(Long petId) {
        return "/api/v1/pets/" + petId + "/care-schedules";
    }
}
