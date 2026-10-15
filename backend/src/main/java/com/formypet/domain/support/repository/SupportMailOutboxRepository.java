package com.formypet.domain.support.repository;

import com.formypet.domain.support.entity.SupportMailOutbox;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SupportMailOutboxRepository extends JpaRepository<SupportMailOutbox, Long> {}
