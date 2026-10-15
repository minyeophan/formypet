package com.formypet.domain.notification.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcType;
import org.hibernate.type.descriptor.jdbc.LocalDateTimeJdbcType;

/** Registration and invalidation use atomic repository commands. */
@Entity
@Table(name = "device_tokens")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class DeviceToken {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "user_id", nullable = false)
    private Long userId;
    @Column(nullable = false, length = 512, unique = true)
    private String token;
    @Column(nullable = false, length = 20)
    private String platform;
    @Column(nullable = false)
    private boolean enabled;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "created_at", nullable = false, insertable = false, updatable = false)
    private LocalDateTime createdAt;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "updated_at", nullable = false, insertable = false, updatable = false)
    private LocalDateTime updatedAt;
}
