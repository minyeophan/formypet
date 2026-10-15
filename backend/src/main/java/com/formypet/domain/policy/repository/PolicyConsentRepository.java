package com.formypet.domain.policy.repository;

import com.formypet.domain.policy.entity.PolicyConsent;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PolicyConsentRepository extends JpaRepository<PolicyConsent, Long> {
    List<PolicyConsent> findByUserIdOrderByRecordedAtAscIdAsc(long userId);

    @Query("""
            select count(distinct c.action) from PolicyConsent c
            where c.userId=:userId and c.documentType='terms' and c.acceptanceRevision=:revision
            and c.action in ('ACCEPTED','AGE14_CONFIRMED')
            """)
    long acceptedActionCount(@Param("userId") long userId, @Param("revision") String revision);

    // Preserve atomic duplicate suppression and the original DB-generated time/hash.
    // Catching a JPA uniqueness failure would mark the signup transaction rollback-only.
    @Modifying
    @Query(value = """
            INSERT IGNORE INTO policy_consents(user_id,document_type,document_version,acceptance_revision,action,document_hash)
            VALUES (:userId,:type,:version,:revision,:action,:hash)
            """, nativeQuery = true)
    int recordIfAbsent(@Param("userId") long userId, @Param("type") String type,
                       @Param("version") String version, @Param("revision") String revision,
                       @Param("action") String action, @Param("hash") String hash);
}
