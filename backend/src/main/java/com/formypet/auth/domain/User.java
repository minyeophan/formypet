package com.formypet.auth.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.springframework.lang.NonNull;

import java.time.LocalDateTime;

@Entity
@Table(name = "users")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    @Column(nullable = false)
    private String nickname;

    @Column(name = "registration_source", nullable = false, length = 20)
    private String registrationSource;

    @Column(name = "profile_media_id")
    private Long profileMediaId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @NonNull
    public static User create(String email, String passwordHash, String nickname) {
        User user = new User();
        user.email        = email;
        user.passwordHash = passwordHash;
        user.nickname     = nickname;
        user.registrationSource = "LOCAL";
        user.createdAt    = LocalDateTime.now();
        user.updatedAt    = LocalDateTime.now();
        return user;
    }

    @NonNull
    public static User createOAuth(String email, String passwordHash, String nickname, String registrationSource) {
        User user = new User();
        user.email = email;
        user.passwordHash = passwordHash;
        user.nickname = nickname;
        user.registrationSource = registrationSource;
        user.createdAt = LocalDateTime.now();
        user.updatedAt = LocalDateTime.now();
        return user;
    }

    public void updateNickname(String nickname) {
        this.nickname = nickname;
        this.updatedAt = LocalDateTime.now();
    }

    public void updateProfileMediaId(Long profileMediaId) {
        this.profileMediaId = profileMediaId;
        this.updatedAt = LocalDateTime.now();
    }
}
