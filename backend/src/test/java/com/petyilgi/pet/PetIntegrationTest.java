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
import java.util.HashMap;
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
    void createPetAllowsMissingBirthDate() throws Exception {
        String token = registerAndGetToken("owner-no-birth@example.com", "ownerNoBirth");
        var body = new HashMap<String, Object>();
        body.put("name", "뭉치");
        body.put("species", "dog");

        mockMvc.perform(post(PETS_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.name").value("뭉치"))
                .andExpect(jsonPath("$.data.birthDate").doesNotExist());
    }

    @Test
    void createAndListPetIncludesExtendedProfileFieldsAndClientColors() throws Exception {
        String token = registerAndGetToken("owner-extended@example.com", "ownerExtended");
        var body = new HashMap<String, Object>(petBody("몽이"));
        body.put("breed", "푸들");
        body.put("adoptionDate", "2023-04-01");
        body.put("guardianNickname", "언니");
        body.put("specialStatus", "senior");
        body.put("personality", "낯가리지만 산책을 좋아해요");
        body.put("primaryHospitalName", "튼튼동물병원");
        body.put("accentColor", "#123456");
        body.put("bgLight", "#F1F5F9");

        mockMvc.perform(post(PETS_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.breed").value("푸들"))
                .andExpect(jsonPath("$.data.adoptionDate").value("2023-04-01"))
                .andExpect(jsonPath("$.data.guardianNickname").value("언니"))
                .andExpect(jsonPath("$.data.specialStatus").value("senior"))
                .andExpect(jsonPath("$.data.personality").value("낯가리지만 산책을 좋아해요"))
                .andExpect(jsonPath("$.data.primaryHospitalName").value("튼튼동물병원"))
                .andExpect(jsonPath("$.data.accentColor").value("#123456"))
                .andExpect(jsonPath("$.data.bgLight").value("#F1F5F9"));

        mockMvc.perform(get(PETS_URL).header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].breed").value("푸들"))
                .andExpect(jsonPath("$.data[0].adoptionDate").value("2023-04-01"))
                .andExpect(jsonPath("$.data[0].guardianNickname").value("언니"))
                .andExpect(jsonPath("$.data[0].specialStatus").value("senior"))
                .andExpect(jsonPath("$.data[0].personality").value("낯가리지만 산책을 좋아해요"))
                .andExpect(jsonPath("$.data[0].primaryHospitalName").value("튼튼동물병원"))
                .andExpect(jsonPath("$.data[0].accentColor").value("#123456"))
                .andExpect(jsonPath("$.data[0].bgLight").value("#F1F5F9"));
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
    void updatePetClearsBirthDateWhenUnknownIsTrue() throws Exception {
        String token = registerAndGetToken("owner-birth-unknown@example.com", "ownerBirthUnknown");

        MvcResult created = mockMvc.perform(post(PETS_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(petBody("뭉치"))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.birthDate").value("2022-03-15"))
                .andReturn();

        var data = (Map<?, ?>) objectMapper.readValue(
                created.getResponse().getContentAsString(), Map.class).get("data");
        Long petId = ((Number) data.get("id")).longValue();
        var body = new HashMap<String, Object>();
        body.put("name", "뭉치");
        body.put("birthDateUnknown", true);

        mockMvc.perform(put(PETS_URL + "/" + petId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.birthDate").doesNotExist());
    }

    @Test
    void updatePetKeepsBirthDateWhenFieldIsOmitted() throws Exception {
        String token = registerAndGetToken("owner-birth-keep@example.com", "ownerBirthKeep");

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
                .andExpect(jsonPath("$.data.name").value("코코"))
                .andExpect(jsonPath("$.data.birthDate").value("2022-03-15"));
    }

    @Test
    void updatePetChangesExtendedProfileFieldsAndColors() throws Exception {
        String token = registerAndGetToken("owner-update-extended@example.com", "ownerUpdateExtended");

        MvcResult created = mockMvc.perform(post(PETS_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(petBody("뭉치"))))
                .andExpect(status().isCreated())
                .andReturn();

        var data = (Map<?, ?>) objectMapper.readValue(
                created.getResponse().getContentAsString(), Map.class).get("data");
        Long petId = ((Number) data.get("id")).longValue();
        var body = new HashMap<String, Object>();
        body.put("name", "코코");
        body.put("species", "cat");
        body.put("birthDate", "2021-05-10");
        body.put("weight", 4.8);
        body.put("breed", "코리안숏헤어");
        body.put("adoptionDate", "2022-01-02");
        body.put("guardianNickname", "집사");
        body.put("specialStatus", "pregnant");
        body.put("personality", "호기심이 많아요");
        body.put("primaryHospitalName", "고양이병원");
        body.put("accentColor", "#ABCDEF");
        body.put("bgLight", "#EEF6FF");

        mockMvc.perform(put(PETS_URL + "/" + petId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value("코코"))
                .andExpect(jsonPath("$.data.species").value("cat"))
                .andExpect(jsonPath("$.data.birthDate").value("2021-05-10"))
                .andExpect(jsonPath("$.data.weight").value(4.8))
                .andExpect(jsonPath("$.data.breed").value("코리안숏헤어"))
                .andExpect(jsonPath("$.data.adoptionDate").value("2022-01-02"))
                .andExpect(jsonPath("$.data.guardianNickname").value("집사"))
                .andExpect(jsonPath("$.data.specialStatus").value("pregnant"))
                .andExpect(jsonPath("$.data.personality").value("호기심이 많아요"))
                .andExpect(jsonPath("$.data.primaryHospitalName").value("고양이병원"))
                .andExpect(jsonPath("$.data.accentColor").value("#ABCDEF"))
                .andExpect(jsonPath("$.data.bgLight").value("#EEF6FF"));
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
