package com.formypet.domain.user.service.impl;

import com.formypet.domain.user.service.UserBlockService;
import com.formypet.domain.user.dto.response.BlockedUser;
import com.formypet.domain.user.dto.response.BlockList;

import com.formypet.domain.user.repository.UserRepository;
import com.formypet.global.exception.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import com.formypet.domain.user.repository.UserBlockRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class UserBlockServiceImpl implements UserBlockService {
    private final UserBlockRepository blocks;
    private final UserRepository users;


    @Transactional(readOnly = true)
    public BlockList list(Long actorId) {
        Long viewer = userId(actorId);
        return new BlockList(blocks.listBlocked(viewer).stream()
                .map(row -> new BlockedUser(row.userId(), row.nickname())).toList());
    }

    @Transactional
    public void block(Long actorId, Long target) {
        Long viewer = userId(actorId);
        if (viewer.equals(target)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "self-user-block", "Invalid User Block",
                    "You cannot block yourself.", "SELF_USER_BLOCK");
        }
        if (!users.existsById(target)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "user-not-found", "User Not Found",
                    "User not found.", "USER_NOT_FOUND");
        }
        blocks.addIfAbsent(viewer, target);
    }

    @Transactional
    public void unblock(Long actorId, Long target) {
        blocks.remove(userId(actorId), target);
    }

    private Long userId(Long actorId) {
        return users.findById(actorId).orElseThrow(() -> new IllegalStateException("User not found.")).getId();
    }
}
