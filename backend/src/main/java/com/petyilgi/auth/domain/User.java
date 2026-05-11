package com.petyilgi.auth.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

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

    @Column(name = "profile_media_id")
    private Long profileMediaId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    public static User create(String email, String passwordHash, String nickname) {
        User user = new User();
        user.email        = email;
        user.passwordHash = passwordHash;
        user.nickname     = nickname;
        user.createdAt    = LocalDateTime.now();
        user.updatedAt    = LocalDateTime.now();
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
