package com.formypet.domain.user.service;

import com.formypet.domain.user.dto.response.BlockList;

public interface UserBlockService {
    BlockList list(Long actorId);
    void block(Long actorId, Long target);
    void unblock(Long actorId, Long target);
}
