package com.formypet.domain.notification.repository;

import com.formypet.domain.notification.entity.DeviceToken;
import com.formypet.domain.notification.repository.query.DeviceTokenSnapshot;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface DeviceTokenRepository extends JpaRepository<DeviceToken, Long> {
    Optional<DeviceToken> findByToken(String token);

    @Query("select new com.formypet.domain.notification.repository.query.DeviceTokenSnapshot(t.token,t.updatedAt) "
            + "from DeviceToken t where t.userId=:userId and t.enabled=true")
    List<DeviceTokenSnapshot> activeSnapshots(@Param("userId") long userId);
}
