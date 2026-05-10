package com.petyilgi.pet.repository;

import com.petyilgi.pet.domain.Pet;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface PetRepository extends JpaRepository<Pet, Long> {
    List<Pet> findByUserId(Long userId);
    Optional<Pet> findByIdAndUserId(Long id, Long userId);
}
