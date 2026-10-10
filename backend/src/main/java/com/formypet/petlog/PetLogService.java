package com.formypet.petlog;

import com.formypet.auth.domain.User;
import com.formypet.auth.repository.UserRepository;
import com.formypet.common.exception.NotFoundException;
import com.formypet.common.exception.ApiException;
import com.formypet.common.time.UtcTime;
import com.formypet.media.MediaService;
import com.formypet.pet.domain.Pet;
import com.formypet.pet.repository.PetRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.PreparedStatement;
import java.sql.Statement;
import java.time.*;
import java.util.*;

@Service
@RequiredArgsConstructor
public class PetLogService {
    private final JdbcTemplate jdbc;
    private final PetRepository pets;
    private final UserRepository users;
    private final MediaService media;

    @Transactional
    public PetLogResponse create(Long userId, Long petId, PetLogCreateRequest request) {
        media.lockPetLogMediaOwner(userId);
        Pet pet = owned(userId, petId);
        KeyHolder key = new GeneratedKeyHolder();
        LocalDateTime entryAt = LocalDateTime.of(request.date(), request.time());
        jdbc.update(connection -> {
            PreparedStatement ps = connection.prepareStatement("INSERT INTO pet_logs(pet_id,user_id,entry_at,note) VALUES (?,?,?,?)", Statement.RETURN_GENERATED_KEYS);
            ps.setLong(1, pet.getId()); ps.setLong(2, userId); ps.setObject(3, entryAt); ps.setString(4, request.note()); return ps;
        }, key);
        long id = Objects.requireNonNull(key.getKey()).longValue();
        attachPhotos(userId, petId, id, request.mediaIds());
        jdbc.update("INSERT INTO pet_log_preferences(pet_id,user_id,example_dismissed,updated_at) VALUES (?,?,TRUE,?) ON DUPLICATE KEY UPDATE example_dismissed=TRUE,updated_at=VALUES(updated_at)", petId,userId,UtcTime.toDatabase(Instant.now()));
        return get(userId, petId, id);
    }

    @Transactional(readOnly = true)
    public PetLogPageResponse list(Long userId, Long petId, Integer year, Integer month, int limit, String cursor) {
        owned(userId, petId);
        if (limit < 1 || limit > 50) throw new IllegalArgumentException("limit은 1~50이어야 합니다.");
        if (year != null && (year < 1 || year > 9998)) throw new IllegalArgumentException("연도를 확인해 주세요.");
        if (month != null && (year == null || month < 1 || month > 12)) throw new IllegalArgumentException("월 조회에는 올바른 연도가 필요합니다.");
        StringBuilder sql = new StringBuilder("SELECT id,pet_id,entry_at,note,version,created_at FROM pet_logs WHERE pet_id=?");
        List<Object> args = new ArrayList<>(List.of(petId));
        if (year != null) { sql.append(" AND entry_at>=? AND entry_at<?"); args.add(LocalDate.of(year, month == null ? 1 : month, 1).atStartOfDay()); args.add(month == null ? LocalDate.of(year + 1,1,1).atStartOfDay() : LocalDate.of(year,month,1).plusMonths(1).atStartOfDay()); }
        if (cursor != null && !cursor.isBlank()) {
            String decoded;
            try { decoded = new String(java.util.Base64.getUrlDecoder().decode(cursor), java.nio.charset.StandardCharsets.UTF_8); }
            catch (IllegalArgumentException e) { throw new IllegalArgumentException("페이지 커서가 올바르지 않습니다."); }
            String[] parts = decoded.split("\\|", -1);
            if (parts.length != 2) throw new IllegalArgumentException("페이지 커서가 올바르지 않습니다.");
            LocalDateTime before;
            long beforeId;
            try { before=LocalDateTime.parse(parts[0]); beforeId=Long.parseLong(parts[1]); }
            catch (RuntimeException e) { throw new IllegalArgumentException("페이지 커서가 올바르지 않습니다."); }
            sql.append(" AND (entry_at<? OR (entry_at=? AND id<?))");
            args.add(before); args.add(before); args.add(beforeId);
        }
        sql.append(" ORDER BY entry_at DESC,id DESC LIMIT ?"); args.add(limit+1);
        List<PetLogResponse> found = jdbc.query(sql.toString(), (rs,n) -> response(rs.getLong("id"),rs.getLong("pet_id"),rs.getTimestamp("entry_at").toLocalDateTime(),rs.getString("note"),rs.getLong("version"),rs.getTimestamp("created_at").toInstant()), args.toArray());
        boolean more=found.size()>limit;
        if (more) found=found.subList(0,limit);
        String next=null;
        if(more&&!found.isEmpty()) { PetLogResponse last=found.getLast(); LocalDateTime at=LocalDateTime.of(last.date(),last.time()); next=java.util.Base64.getUrlEncoder().withoutPadding().encodeToString((at+"|"+last.id()).getBytes(java.nio.charset.StandardCharsets.UTF_8)); }
        List<Integer> years=jdbc.queryForList("SELECT DISTINCT YEAR(entry_at) FROM pet_logs WHERE pet_id=? ORDER BY YEAR(entry_at) DESC",Integer.class,petId);
        Boolean hasAny=jdbc.queryForObject("SELECT EXISTS(SELECT 1 FROM pet_logs WHERE pet_id=?)",Boolean.class,petId);
        return new PetLogPageResponse(List.copyOf(found),next,years,Boolean.TRUE.equals(hasAny));
    }

    @Transactional(readOnly = true)
    public PetLogResponse get(Long userId, Long petId, Long id) {
        owned(userId, petId);
        var rows = jdbc.query("SELECT id,pet_id,entry_at,note,version,created_at FROM pet_logs WHERE id=? AND pet_id=?", (rs,n)->response(rs.getLong("id"),rs.getLong("pet_id"),rs.getTimestamp("entry_at").toLocalDateTime(),rs.getString("note"),rs.getLong("version"),rs.getTimestamp("created_at").toInstant()), id, petId);
        if (rows.isEmpty()) throw new NotFoundException("Pet log not found.", "PET_LOG_NOT_FOUND");
        return rows.getFirst();
    }

    @Transactional
    public PetLogResponse update(Long userId, Long petId, Long id, PetLogUpdateRequest request) {
        if (request.version() < 0) throw new IllegalArgumentException("기록 버전이 올바르지 않습니다.");
        media.lockPetLogMediaOwner(userId);
        owned(userId, petId);
        int changed = jdbc.update("UPDATE pet_logs SET entry_at=?,note=?,version=version+1,updated_at=? WHERE id=? AND pet_id=? AND version=?",
                LocalDateTime.of(request.date(),request.time()), request.note(), UtcTime.toDatabase(Instant.now()), id, petId, request.version());
        if (changed != 1) throw conflict();
        attachPhotos(userId, petId, id, request.mediaIds());
        return get(userId, petId, id);
    }

    @Transactional
    public void delete(Long userId, Long petId, Long id, long expectedVersion) {
        media.lockPetLogMediaOwner(userId);
        owned(userId, petId);
        var versions = jdbc.query("SELECT version FROM pet_logs WHERE id=? AND pet_id=? FOR UPDATE",
                (rs,n) -> rs.getLong("version"), id, petId);
        if (versions.isEmpty()) throw new NotFoundException("Pet log not found.", "PET_LOG_NOT_FOUND");
        if (versions.getFirst() != expectedVersion) {
            throw conflict();
        }
        media.deletePetLogMedia(userId, id);
        int count = jdbc.update("DELETE FROM pet_logs WHERE id=? AND pet_id=? AND version=?",
                id, petId, expectedVersion);
        if (count == 0) throw conflict();
    }

    private ApiException conflict() {
        return new ApiException(org.springframework.http.HttpStatus.CONFLICT, "pet-log-conflict",
                "Pet log changed", "기록이 다른 곳에서 변경되었어요.", "PET_LOG_CONFLICT");
    }

    @Transactional
    public boolean dismissExample(Long userId, Long petId) {
        owned(userId, petId);
        jdbc.update("INSERT INTO pet_log_preferences(pet_id,user_id,example_dismissed) VALUES (?,?,TRUE) ON DUPLICATE KEY UPDATE example_dismissed=TRUE,updated_at=VALUES(updated_at)", petId, userId);
        return true;
    }

    @Transactional(readOnly=true)
    public boolean exampleDismissed(Long userId,Long petId){
        owned(userId,petId);
        Integer count=jdbc.queryForObject("SELECT COUNT(*) FROM pet_log_preferences WHERE pet_id=? AND user_id=? AND example_dismissed=TRUE",Integer.class,petId,userId);
        return count!=null&&count>0;
    }

    private void attachPhotos(Long userId, Long petId, Long logId, List<Long> ids) {
        List<Long> oldIds=jdbc.queryForList("SELECT media_id FROM pet_log_media WHERE pet_log_id=? FOR UPDATE",Long.class,logId);
        for(Long mediaId:ids) {
            int draft=jdbc.update("UPDATE media_resources SET media_kind='PET_LOG' WHERE id=? AND user_id=? AND pet_id=? AND media_kind='PET_LOG_DRAFT' AND record_id IS NULL",mediaId,userId,petId);
            if(draft==0 && !oldIds.contains(mediaId)) throw new AccessDeniedException("사진을 이 기록에 첨부할 수 없습니다.");
        }
        jdbc.update("DELETE FROM pet_log_media WHERE pet_log_id=?",logId);
        for(int position=0;position<ids.size();position++) {
            int[] dimensions=media.imageDimensions(userId,ids.get(position));
            jdbc.update("INSERT INTO pet_log_media(media_id,pet_log_id,position,width,height) VALUES (?,?,?,?,?)",ids.get(position),logId,position,dimensions[0],dimensions[1]);
        }
        List<Long> removed=oldIds.stream().filter(id->!ids.contains(id)).toList();
        media.deletePetLogMediaIds(userId,removed);
    }
    private PetLogResponse response(long id,long petId,LocalDateTime at,String note,long version,Instant created) {
        List<PetLogPhotoResponse> photos=jdbc.query("SELECT m.id,pm.position,pm.width,pm.height FROM pet_log_media pm JOIN media_resources m ON m.id=pm.media_id WHERE pm.pet_log_id=? ORDER BY pm.position",(rs,n)->new PetLogPhotoResponse(rs.getLong("id"),"/api/v1/media/"+rs.getLong("id"),rs.getInt("position"),rs.getInt("width"),rs.getInt("height")),id);
        return new PetLogResponse(id,petId,at.toLocalDate(),at.toLocalTime(),note,version,photos,created,null);
    }
    private Pet owned(Long userId,Long petId){ User user=users.findById(userId).orElseThrow(); return pets.findById(petId).filter(p->p.isOwnedBy(user.getId())).orElseThrow(()->new AccessDeniedException("Cannot access this pet.")); }
}
