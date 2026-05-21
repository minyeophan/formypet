package com.petyilgi.pet;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.petyilgi.auth.repository.RefreshTokenRepository;
import com.petyilgi.auth.repository.UserRepository;
import com.petyilgi.support.IntegrationTestSupport;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.util.Map;

import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@AutoConfigureMockMvc
@Transactional
class PetIntegrationTest extends IntegrationTestSupport {

    @Autowired MockMvc mockMvc;
    @Autowired ObjectMapper objectMapper;
    @Autowired UserRepository userRepository;
    @Autowired RefreshTokenRepository refreshTokenRepository;

    private static final String PETS_URL    = "/api/v1/pets";
    private static final String AUTH_URL    = "/api/v1/auth/register";

    @BeforeEach
    void setUp() {
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();
    }

    // 테스트용 유저 등록 후 accessToken 반환
    private String registerAndGetToken(String email, String nickname) throws Exception {
        var body = Map.of("email", email, "password", "Password1!", "nickname", nickname);
        MvcResult result = mockMvc.perform(post(AUTH_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isCreated())
                .andReturn();
        var data = (Map<?, ?>) objectMapper.readValue(
                result.getResponse().getContentAsString(), Map.class).get("data");
        return (String) data.get("accessToken");
    }

    private Map<String, Object> petBody(String name) {
        return Map.of(
                "name",      name,
                "species",   "dog",
                "birthDate", "2022-03-15"
        );
    }

    @Test
    void createPetReturnsCreatedPet() throws Exception {
        String token = registerAndGetToken("owner@example.com", "owner");

        mockMvc.perform(post(PETS_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(petBody("뭉치"))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.name").value("뭉치"))
                .andExpect(jsonPath("$.data.species").value("dog"))
                .andExpect(jsonPath("$.data.accentColor").isNotEmpty())
                .andExpect(jsonPath("$.data.bgLight").isNotEmpty());
    }

    @Test
    void listPetsReturnsOnlyOwnedPets() throws Exception {
        String tokenA = registerAndGetToken("a@example.com", "userA");
        String tokenB = registerAndGetToken("b@example.com", "userB");

        // A가 펫 2마리 등록
        mockMvc.perform(post(PETS_URL).header("Authorization", "Bearer " + tokenA)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(petBody("뭉치")))).andExpect(status().isCreated());
        mockMvc.perform(post(PETS_URL).header("Authorization", "Bearer " + tokenA)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(petBody("코코")))).andExpect(status().isCreated());

        // B가 펫 1마리 등록
        mockMvc.perform(post(PETS_URL).header("Authorization", "Bearer " + tokenB)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(petBody("초코")))).andExpect(status().isCreated());

        // A 조회 → 2마리만
        mockMvc.perform(get(PETS_URL).header("Authorization", "Bearer " + tokenA))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data", hasSize(2)));

        // B 조회 → 1마리만
        mockMvc.perform(get(PETS_URL).header("Authorization", "Bearer " + tokenB))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data", hasSize(1)));
    }

    @Test
    void listPetsIncludesLatestPetProfileImageUrl() throws Exception {
        String token = registerAndGetToken("pet-photo-list@example.com", "photoOwner");

        MvcResult created = mockMvc.perform(post(PETS_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(petBody("Mochi"))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.profileImageUrl").doesNotExist())
                .andReturn();

        var data = (Map<?, ?>) objectMapper.readValue(
                created.getResponse().getContentAsString(), Map.class).get("data");
        Long petId = ((Number) data.get("id")).longValue();

        mockMvc.perform(multipart(PETS_URL + "/" + petId + "/media")
                        .file(new MockMultipartFile("file", "first.png", MediaType.IMAGE_PNG_VALUE,
                                "first-image".getBytes(StandardCharsets.UTF_8)))
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isCreated());

        MvcResult latestUpload = mockMvc.perform(multipart(PETS_URL + "/" + petId + "/media")
                        .file(new MockMultipartFile("file", "latest.png", MediaType.IMAGE_PNG_VALUE,
                                "latest-image".getBytes(StandardCharsets.UTF_8)))
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isCreated())
                .andReturn();
        var latestData = (Map<?, ?>) objectMapper.readValue(
                latestUpload.getResponse().getContentAsString(), Map.class).get("data");
        String latestUrl = latestData.get("url").toString();

        mockMvc.perform(get(PETS_URL).header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].profileImageUrl").value(latestUrl));
    }

    @Test
    void updatePetNameSucceeds() throws Exception {
        String token = registerAndGetToken("owner2@example.com", "owner2");

        MvcResult created = mockMvc.perform(post(PETS_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(petBody("뭉치"))))
                .andExpect(status().isCreated())
                .andReturn();

        var data = (Map<?, ?>) objectMapper.readValue(
                created.getResponse().getContentAsString(), Map.class).get("data");
        Long petId = ((Number) data.get("id")).longValue();

        mockMvc.perform(put(PETS_URL + "/" + petId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("name", "코코"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value("코코"));
    }

    @Test
    void deletePetSoftDeletesAndHidesFromList() throws Exception {
        String token = registerAndGetToken("owner3@example.com", "owner3");

        MvcResult created = mockMvc.perform(post(PETS_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(petBody("뭉치"))))
                .andExpect(status().isCreated())
                .andReturn();

        var data = (Map<?, ?>) objectMapper.readValue(
                created.getResponse().getContentAsString(), Map.class).get("data");
        Long petId = ((Number) data.get("id")).longValue();

        mockMvc.perform(delete(PETS_URL + "/" + petId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        // 삭제 후 목록에 안 보임
        mockMvc.perform(get(PETS_URL).header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data", hasSize(0)));
    }

    @Test
    void accessOtherUsersPetReturns403() throws Exception {
        String tokenA = registerAndGetToken("a2@example.com", "userA2");
        String tokenB = registerAndGetToken("b2@example.com", "userB2");

        MvcResult created = mockMvc.perform(post(PETS_URL)
                        .header("Authorization", "Bearer " + tokenA)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(petBody("뭉치"))))
                .andExpect(status().isCreated())
                .andReturn();

        var data = (Map<?, ?>) objectMapper.readValue(
                created.getResponse().getContentAsString(), Map.class).get("data");
        Long petId = ((Number) data.get("id")).longValue();

        // B가 A의 펫 수정 시도 → 403
        mockMvc.perform(put(PETS_URL + "/" + petId)
                        .header("Authorization", "Bearer " + tokenB)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("name", "해킹"))))
                .andExpect(status().isForbidden());

        // B가 A의 펫 삭제 시도 → 403
        mockMvc.perform(delete(PETS_URL + "/" + petId)
                        .header("Authorization", "Bearer " + tokenB))
                .andExpect(status().isForbidden());
    }
}
