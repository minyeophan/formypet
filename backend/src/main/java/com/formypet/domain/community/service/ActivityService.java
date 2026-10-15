package com.formypet.domain.community.service;

import com.formypet.domain.community.dto.*;
import com.formypet.domain.community.dto.request.*;
import com.formypet.domain.community.dto.response.*;
import org.springframework.web.multipart.MultipartFile;
import java.util.List;

public interface ActivityService {
    public com.formypet.domain.community.dto.response.MyActivityResponse myActivities(
            Long actorId, String type, String cursor, int limit);
}
