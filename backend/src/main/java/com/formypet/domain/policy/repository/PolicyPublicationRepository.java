package com.formypet.domain.policy.repository;

import com.formypet.domain.policy.entity.PolicyPublication;
import com.formypet.domain.policy.entity.PolicyPublicationId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;

public interface PolicyPublicationRepository extends JpaRepository<PolicyPublication, PolicyPublicationId> {
    // Publication boundaries use the database clock, including microseconds.
    @Query(value = "SELECT * FROM policy_publications WHERE published_at<=UTC_TIMESTAMP(6) ORDER BY effective_at,published_at,document_version", nativeQuery = true)
    List<PolicyPublication> findPublished();

    @Query(value = "SELECT COUNT(DISTINCT document_type) FROM policy_publications WHERE document_type IN ('terms','privacy') AND published_at<=UTC_TIMESTAMP(6) AND effective_at<=UTC_TIMESTAMP(6)", nativeQuery = true)
    int effectiveTypeCount();

    // Current read is necessary after waiting for the singleton publication lock.
    @Query(value = "SELECT * FROM policy_publications WHERE document_type=:type AND document_version=:version FOR UPDATE", nativeQuery = true)
    Optional<PolicyPublication> findCurrentForUpdate(@Param("type") String type, @Param("version") String version);
}
