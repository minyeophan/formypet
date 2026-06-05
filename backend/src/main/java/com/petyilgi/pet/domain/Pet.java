package com.petyilgi.pet.domain;

import com.petyilgi.auth.domain.User;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.SQLRestriction;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "pets")
@SQLRestriction("is_deleted = false")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Pet {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false, length = 50)
    private String name;

    @Column(nullable = false, length = 30)
    private String species;

    @Column(name = "birth_date")
    private LocalDate birthDate;

    @Column(length = 80)
    private String breed;

    @Column(name = "adoption_date")
    private LocalDate adoptionDate;

    @Enumerated(EnumType.STRING)
    private Gender gender;

    @Column(precision = 5, scale = 2)
    private BigDecimal weight;

    @Column(name = "animal_registration_number", length = 20)
    private String animalRegistrationNumber;

    private Boolean neutered;

    @Column(columnDefinition = "TEXT")
    private String diseases;

    @Column(name = "special_notes", columnDefinition = "TEXT")
    private String specialNotes;

    @Column(name = "guardian_nickname", length = 30)
    private String guardianNickname;

    @Column(name = "special_status", length = 30)
    private String specialStatus;

    @Column(columnDefinition = "TEXT")
    private String personality;

    @Column(name = "primary_hospital_name", length = 100)
    private String primaryHospitalName;

    @Column(name = "accent_color", nullable = false, length = 7)
    private String accentColor;

    @Column(name = "bg_light", nullable = false, length = 7)
    private String bgLight;

    @Column(name = "is_deleted", nullable = false)
    private boolean deleted = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    public static Pet create(User user, String name, String species, LocalDate birthDate,
                             String accentColor, String bgLight) {
        Pet pet = new Pet();
        pet.user        = user;
        pet.name        = name;
        pet.species     = species;
        pet.birthDate   = birthDate;
        pet.accentColor = accentColor;
        pet.bgLight     = bgLight;
        pet.createdAt   = LocalDateTime.now();
        pet.updatedAt   = LocalDateTime.now();
        return pet;
    }

    public void updateName(String name) {
        this.name      = name;
        this.updatedAt = LocalDateTime.now();
    }

    public void update(String name, String species, LocalDate birthDate,
                       Gender gender, BigDecimal weight, String animalRegistrationNumber,
                       Boolean neutered, String diseases, String specialNotes,
                       String breed, LocalDate adoptionDate, String guardianNickname,
                       String specialStatus, String personality, String primaryHospitalName,
                       String accentColor, String bgLight) {
        this.name                       = name;
        this.species                    = species;
        this.birthDate                  = birthDate;
        this.gender                     = gender;
        this.weight                     = weight;
        this.animalRegistrationNumber   = animalRegistrationNumber;
        this.neutered                   = neutered;
        this.diseases                   = diseases;
        this.specialNotes               = specialNotes;
        this.breed                      = breed;
        this.adoptionDate               = adoptionDate;
        this.guardianNickname           = guardianNickname;
        this.specialStatus              = specialStatus;
        this.personality                = personality;
        this.primaryHospitalName        = primaryHospitalName;
        this.accentColor                = accentColor;
        this.bgLight                    = bgLight;
        this.updatedAt                  = LocalDateTime.now();
    }

    public void softDelete() {
        this.deleted   = true;
        this.updatedAt = LocalDateTime.now();
    }

    public boolean isOwnedBy(Long userId) {
        return user.getId().equals(userId);
    }
}
