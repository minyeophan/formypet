package com.formypet.domain.policy.service;
import com.formypet.common.exception.ApiException;
import com.formypet.domain.policy.dto.response.PolicyCatalogResponse;
import com.formypet.domain.policy.dto.response.PolicyDocumentResponse;
import org.springframework.http.HttpStatus;
public interface PolicyCatalog {
    PolicyCatalogResponse status();
    boolean enforced();
    PolicyDocumentResponse current(String type);
    PolicyDocumentResponse version(String type, String version);
    static ApiException error(HttpStatus status, String code, String detail) {
        return new ApiException(status, "policy", "Policy", detail, code);
    }
}
