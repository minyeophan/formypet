package com.formypet.community;

import com.formypet.common.exception.GlobalExceptionHandler;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.security.web.method.annotation.AuthenticationPrincipalArgumentResolver;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.MissingServletRequestParameterException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class MyActivityControllerTest {

    @Test
    void missingTypeReturnsBadRequestWithInvalidInput() throws Exception {
        CommunityService service = mock(CommunityService.class);
        MockMvc mockMvc = MockMvcBuilders.standaloneSetup(new MyActivityController(service))
                .setControllerAdvice(new GlobalExceptionHandler())
                .setCustomArgumentResolvers(new AuthenticationPrincipalArgumentResolver())
                .build();

        mockMvc.perform(get("/api/v1/me/community/activities"))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.errorCode").value("INVALID_INPUT"))
                .andExpect(result -> {
                    assertThat(result.getResolvedException())
                            .isInstanceOf(MissingServletRequestParameterException.class);
                    var exception = (MissingServletRequestParameterException) result.getResolvedException();
                    assertThat(exception.getParameterName()).isEqualTo("type");
                });

        verifyNoInteractions(service);
    }
}
