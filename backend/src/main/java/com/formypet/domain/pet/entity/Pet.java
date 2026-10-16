package com.formypet.domain.pet.entity;

import com.formypet.domain.user.entity.User;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.SQLRestriction;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.Instant;

@Entity
@Table(name = "pets")
@SQLRestriction("is_deleted = false")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Pet {
    private static final String[] ACCENT_COLORS = {
            "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7",
            "#DDA0DD", "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E9"
    };

    private static final String[] BG_LIGHTS = {
            "#FFE5E5", "#E0F7F5", "#E0F4FB", "#EAF7EE", "#FFF9E6",
            "#F5E6F5", "#E6F7F4", "#FEF9E7", "#F0E6F6", "#E8F4FD"
    };



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
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    public static Pet create(User user, String name, String species, LocalDate birthDate,
                             String accentColor, String bgLight, long existingPetCount) {
        int colorIdx = (int) (existingPetCount % ACCENT_COLORS.length);
        Pet pet = new Pet();
        pet.user        = user;
        pet.name        = name;
        pet.species     = species;
        pet.birthDate   = birthDate;
        pet.accentColor = fallbackIfBlank(accentColor, ACCENT_COLORS[colorIdx]);
        pet.bgLight     = fallbackIfBlank(bgLight, BG_LIGHTS[colorIdx]);
        pet.createdAt   = Instant.now();
        pet.updatedAt   = Instant.now();
        return pet;
    }

    public void updateName(String name) {
        this.name      = name;
        this.updatedAt = Instant.now();
    }

    public void update(String name, String species, LocalDate birthDate, Boolean birthDateUnknown,
                       Gender gender, BigDecimal weight, String animalRegistrationNumber,
                       Boolean neutered, String diseases, String specialNotes,
                       String breed, LocalDate adoptionDate, String guardianNickname,
                       String specialStatus, String personality, String primaryHospitalName,
                       String accentColor, String bgLight) {
        this.name                       = name;
        this.species                    = species != null ? species : this.species;
        this.birthDate                  = Boolean.TRUE.equals(birthDateUnknown) ? null
                : birthDate != null ? birthDate : this.birthDate;
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
        this.accentColor                = fallbackIfBlank(accentColor, this.accentColor);
        this.bgLight                    = fallbackIfBlank(bgLight, this.bgLight);
        this.updatedAt                  = Instant.now();
    }

    public void softDelete() {
        this.deleted   = true;
        this.updatedAt = Instant.now();
    }

    private static String fallbackIfBlank(String value, String fallback) {
        return value == null || value.isBlank() ? fallback : value;
    }

    public boolean isOwnedBy(Long userId) {
        return user.getId().equals(userId);
    }
}
