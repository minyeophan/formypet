package com.formypet.domain.petlog.repository;

import com.formypet.domain.petlog.entity.PetLog;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PetLogRepository extends JpaRepository<PetLog, Long>, PetLogCurrentReads {}
