package com.formypet.domain.community.service;

import com.formypet.domain.community.dto.*;
import com.formypet.domain.community.dto.request.*;
import com.formypet.domain.community.dto.response.*;
import org.springframework.web.multipart.MultipartFile;
import java.util.List;

public interface ReactionService {
    public PostLikeResponse toggleLike(Long actorId, Long postId);
    public PostResponse vote(Long actorId, Long postId, Long optionId);
}
