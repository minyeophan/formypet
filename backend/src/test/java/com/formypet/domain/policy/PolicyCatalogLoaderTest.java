package com.formypet.domain.policy;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.formypet.domain.policy.config.PolicyCatalogLoader;
import com.formypet.domain.policy.dto.response.PolicyDocumentResponse;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ByteArrayResource;
import static org.assertj.core.api.Assertions.*;

class PolicyCatalogLoaderTest {
    private final ObjectMapper json = new ObjectMapper().findAndRegisterModules();
    private final Instant time = Instant.parse("2000-01-01T00:00:00Z");

    @Test void validReleasePreservesDocumentsAndActivationFlag() throws Exception {
        var doc = document("v1", "r1", time);
        var loader = load(true, List.of(doc), true);
        assertThat(loader.source().documents()).containsExactly(doc);
        assertThat(loader.enforcement()).isTrue();
    }

    @Test void unpublishedCatalogCannotActivateEnforcement() {
        assertThatThrownBy(() -> load(false, List.of(), true))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("Cannot activate an unpublished policy catalog");
    }

    @Test void missingDocumentListIsRejected() {
        assertThatThrownBy(() -> load(false, null, false)).isInstanceOf(IllegalStateException.class)
                .hasMessage("Policy documents are required");
    }

    @Test void duplicateVersionIsRejected() {
        var doc = document("v1", "r1", time);
        assertThatThrownBy(() -> load(true, List.of(doc, doc), false))
                .isInstanceOf(IllegalStateException.class).hasMessage("Invalid policy catalog");
    }

    @Test void invalidRevisionVersionPrecisionAndTimeOrderAreRejected() {
        for (var doc : List.of(document("v1", "", time), document("bad/version", "r1", time),
                document("v1", "r1", time.plusNanos(1)), document("v1", "r1", time.minusSeconds(1)))) {
            assertThatThrownBy(() -> load(true, List.of(doc), false))
                    .isInstanceOf(IllegalStateException.class).hasMessage("Invalid policy catalog");
        }
    }

    private PolicyDocumentResponse document(String version, String revision, Instant effective) {
        return new PolicyDocumentResponse("terms", version, "TEST", "TEST FIXTURE ONLY", time, effective, revision);
    }

    private PolicyCatalogLoader load(boolean published, List<PolicyDocumentResponse> docs, boolean enforcement) throws Exception {
        var bytes = json.writeValueAsBytes(new PolicyCatalogLoader.Source(published, docs));
        return new PolicyCatalogLoader(json, new ByteArrayResource(bytes), enforcement);
    }
}
