package com.formypet.auth.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.springframework.lang.NonNull;

import java.time.Instant;

@Entity
@org.hibernate.annotations.DynamicUpdate
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

    @Column(name = "auth_version", nullable = false, updatable = false)
    private long authVersion;

    @Column(name = "account_status", nullable = false, length = 20)
    private String accountStatus = "ACTIVE";

    @Column(nullable = false)
    private String nickname;

    @Column(name = "registration_source", nullable = false, length = 20)
    private String registrationSource;

    @Column(nullable = false, length = 20)
    private String role = "USER";

    public boolean isAdmin() {
        return "ADMIN".equals(role);
    }

    @Column(name = "profile_media_id")
    private Long profileMediaId;

    @Column(name = "media_bytes_used", nullable = false)
    private long mediaBytesUsed;

    @Column(name = "media_items_used", nullable = false)
    private int mediaItemsUsed;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @NonNull
    public static User create(String email, String passwordHash, String nickname) {
        User user = new User();
        user.email        = email;
        user.passwordHash = passwordHash;
        user.nickname     = nickname;
        user.registrationSource = "LOCAL";
        user.createdAt    = Instant.now();
        user.updatedAt    = Instant.now();
        return user;
    }

    @NonNull
    public static User createOAuth(String email, String passwordHash, String nickname, String registrationSource) {
        User user = new User();
        user.email = email;
        user.passwordHash = passwordHash;
        user.nickname = nickname;
        user.registrationSource = registrationSource;
        user.createdAt = Instant.now();
        user.updatedAt = Instant.now();
        return user;
    }

    public void updateNickname(String nickname) {
        this.nickname = nickname;
        this.updatedAt = Instant.now();
    }

    public void updateProfileMediaId(Long profileMediaId) {
        this.profileMediaId = profileMediaId;
        this.updatedAt = Instant.now();
    }
}
