package com.formypet.domain.community.service;

import com.formypet.domain.community.dto.*;
import com.formypet.domain.community.dto.request.*;
import com.formypet.domain.community.dto.response.*;
import org.springframework.web.multipart.MultipartFile;
import java.util.List;

public interface PostService {
    public PostResponse create(Long actorId, PostCreateRequest request, List<MultipartFile> files);
    public PostFeedResponse feed(Long actorId, String keyword, String category, String sort, String cursor, int limit);
    public PostResponse detail(Long actorId, Long postId);
    public PostResponse update(Long actorId, Long postId, PostUpdateRequest request);
    public void delete(Long actorId, Long postId);
}
