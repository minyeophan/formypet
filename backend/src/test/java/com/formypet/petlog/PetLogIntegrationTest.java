package com.formypet.petlog;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.formypet.auth.repository.RefreshTokenRepository;
import com.formypet.auth.repository.UserRepository;
import com.formypet.support.IntegrationTestSupport;
import com.formypet.media.MediaService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.annotation.Transactional;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@AutoConfigureMockMvc
@Transactional
@TestPropertySource(properties = "app.media.storage-root=build/pet-log-test-storage")
class PetLogIntegrationTest extends IntegrationTestSupport {
    private static final String PETS="/api/v1/pets";
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper mapper;
    @Autowired UserRepository users;
    @Autowired RefreshTokenRepository refreshTokens;
    @Autowired org.springframework.jdbc.core.JdbcTemplate jdbc;
    @Autowired MediaService mediaService;

    @BeforeEach void reset(){refreshTokens.deleteAll();users.deleteAll();}

    @Test
    void draftPhotosCreateSeparateLogsAndTimelineUsesStableCursorWithoutChangingProfilePhoto() throws Exception {
        String token=register("pet-log-list@example.test");
        long pet=createPet(token);
        String profile="/api/v1/media/"+upload(token,pet,"profile.png","profile-key");
        long firstPhoto=upload(token,pet,"first.png","first-upload-key");
        long first=createLog(token,pet,"2026-01-01","09:00","first",firstPhoto,1);
        long secondPhoto=upload(token,pet,"second.png","second-upload-key");
        long second=createLog(token,pet,"2026-03-01","10:30","second",secondPhoto,2);

        String updateBody=mapper.writeValueAsString(Map.of("date","2026-01-01","time","09:00","note","first edit","mediaIds",new long[]{firstPhoto},"version",0));
        mvc.perform(put(PETS+"/"+pet+"/pet-logs/"+first).header("Authorization","Bearer "+token)
                .header("Idempotency-Key","pet-log-update-first").contentType(MediaType.APPLICATION_JSON).content(updateBody))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.version").value(1));
        mvc.perform(put(PETS+"/"+pet+"/pet-logs/"+first).header("Authorization","Bearer "+token)
                .header("Idempotency-Key","pet-log-update-newer").contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(Map.of("date","2026-01-01","time","09:00","note","newer","mediaIds",new long[]{firstPhoto},"version",1))))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.version").value(2));
        mvc.perform(put(PETS+"/"+pet+"/pet-logs/"+first).header("Authorization","Bearer "+token)
                .header("Idempotency-Key","pet-log-update-stale").contentType(MediaType.APPLICATION_JSON).content(updateBody))
                .andExpect(status().isConflict());
        mvc.perform(put(PETS+"/"+pet+"/pet-logs/"+first).header("Authorization","Bearer "+token)
                .header("Idempotency-Key","pet-log-update-first").contentType(MediaType.APPLICATION_JSON).content(updateBody))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.version").value(2))
                .andExpect(jsonPath("$.data.appliedVersion").value(1)).andExpect(jsonPath("$.data.note").value("newer"));

        mvc.perform(get(PETS+"/"+pet+"/pet-logs/"+first).header("Authorization","Bearer "+token))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.version").value(2))
                .andExpect(jsonPath("$.data.note").value("newer"))
                .andExpect(jsonPath("$.data.photos[0].width").value(2))
                .andExpect(jsonPath("$.data.photos[0].height").value(3));

        mvc.perform(get(PETS).header("Authorization","Bearer "+token))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data[0].profileImageUrl").value(profile));
        mvc.perform(get(PETS+"/"+pet+"/pet-logs").param("limit","1").header("Authorization","Bearer "+token))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.items.length()").value(1))
                .andExpect(jsonPath("$.data.items[0].id").value(second))
                .andExpect(jsonPath("$.data.items[0].photos[0].position").value(0))
                .andExpect(jsonPath("$.data.hasAny").value(true))
                .andExpect(jsonPath("$.data.years[0]").value(2026))
                .andExpect(jsonPath("$.data.nextCursor").isNotEmpty())
                .andDo(result -> {
                    String cursor=mapper.readTree(result.getResponse().getContentAsString()).path("data").path("nextCursor").asText();
                    mvc.perform(get(PETS+"/"+pet+"/pet-logs").param("limit","1").param("cursor",cursor).header("Authorization","Bearer "+token))
                            .andExpect(status().isOk()).andExpect(jsonPath("$.data.items[0].id").value(first));
                });
        mvc.perform(get(PETS+"/"+pet+"/pet-logs/preferences").header("Authorization","Bearer "+token))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data").value(true));

        mvc.perform(delete(PETS+"/"+pet+"/pet-logs/"+first).param("version","1")
                        .header("Authorization","Bearer "+token).header("Idempotency-Key","pet-log-delete-stale"))
                .andExpect(status().isConflict());
        assertThat(jdbc.queryForObject("SELECT version FROM pet_logs WHERE id=?",Long.class,first)).isEqualTo(2L);
        mvc.perform(delete(PETS+"/"+pet+"/pet-logs/"+first).param("version","2")
                        .header("Authorization","Bearer "+token).header("Idempotency-Key","pet-log-delete-current"))
                .andExpect(status().isNoContent());
        mvc.perform(delete(PETS+"/"+pet+"/pet-logs/"+first).param("version","2")
                        .header("Authorization","Bearer "+token).header("Idempotency-Key","pet-log-delete-current"))
                .andExpect(status().isNoContent());
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM pet_logs WHERE id=?",Integer.class,first)).isZero();
    }

    @Test
    void expiredDraftsReturnQuotaOnceAndPetDeletionQueuesAllPetLogFiles() throws Exception {
        String token=register("pet-log-cleanup@example.test");
        long pet=createPet(token);
        long draft=upload(token,pet,"expired.png","expired-draft-key");
        long user=users.findByEmail("pet-log-cleanup@example.test").orElseThrow().getId();
        jdbc.update("UPDATE media_resources SET created_at=UTC_TIMESTAMP(6)-INTERVAL 25 HOUR WHERE id=?",draft);
        assertThat(mediaService.cleanupExpiredPetLogDrafts()).isEqualTo(1);
        assertThat(mediaService.cleanupExpiredPetLogDrafts()).isZero();
        assertThat(jdbc.queryForObject("SELECT media_items_used FROM users WHERE id=?",Integer.class,user)).isZero();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM media_cleanup_queue",Integer.class)).isEqualTo(1);

        long recordPhoto=upload(token,pet,"record.png","record-draft-key");
        createLog(token,pet,"2026-01-01","09:00","note",recordPhoto,3);
        mvc.perform(delete(PETS+"/"+pet).header("Authorization","Bearer "+token)).andExpect(status().isNoContent());
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM pet_logs WHERE pet_id=?",Integer.class,pet)).isZero();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM pet_log_preferences WHERE pet_id=?",Integer.class,pet)).isZero();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM media_resources WHERE pet_id=? AND media_kind IN ('PET_LOG_DRAFT','PET_LOG')",Integer.class,pet)).isZero();
    }

    private String register(String email) throws Exception {
        MvcResult result=mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(Map.of("email",email,"password","Password1!","nickname","logtest"))))
                .andExpect(status().isCreated()).andReturn();
        return mapper.readTree(result.getResponse().getContentAsString()).path("data").path("accessToken").asText();
    }

    private long createPet(String token) throws Exception {
        MvcResult result=mvc.perform(post(PETS).header("Authorization","Bearer "+token).contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\"Mochi\",\"species\":\"dog\",\"birthDate\":\"2022-03-15\"}"))
                .andExpect(status().isCreated()).andReturn();
        return mapper.readTree(result.getResponse().getContentAsString()).path("data").path("id").asLong();
    }

    private long upload(String token,long pet,String name,String key) throws Exception {
        MvcResult result=mvc.perform(multipart(PETS+"/"+pet+"/"+(name.equals("profile.png")?"media":"pet-logs/media"))
                .file(new MockMultipartFile("file",name,MediaType.IMAGE_PNG_VALUE,png()))
                .header("Authorization","Bearer "+token).header("Idempotency-Key",key))
                .andExpect(status().isCreated()).andReturn();
        return mapper.readTree(result.getResponse().getContentAsString()).path("data").path("id").asLong();
    }

    private long createLog(String token,long pet,String date,String time,String note,long mediaId,int uploadNumber) throws Exception {
        MvcResult result=mvc.perform(post(PETS+"/"+pet+"/pet-logs").header("Authorization","Bearer "+token)
                .header("Idempotency-Key","pet-log-create-"+uploadNumber).contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(Map.of("date",date,"time",time,"note",note,"mediaIds",new long[]{mediaId}))))
                .andExpect(status().isCreated()).andReturn();
        return mapper.readTree(result.getResponse().getContentAsString()).path("data").path("id").asLong();
    }

    private byte[] png() throws Exception {
        BufferedImage image=new BufferedImage(2,3,BufferedImage.TYPE_INT_RGB);
        ByteArrayOutputStream out=new ByteArrayOutputStream(); ImageIO.write(image,"png",out); return out.toByteArray();
    }
}
