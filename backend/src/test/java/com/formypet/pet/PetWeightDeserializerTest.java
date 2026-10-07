package com.formypet.pet;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.formypet.pet.dto.PetCreateRequest;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class PetWeightDeserializerTest {
    private final ObjectMapper mapper = new ObjectMapper();

    @Test
    void acceptsJsonNumbersAndNull() throws Exception {
        PetCreateRequest request = mapper.readValue("""
                {"name":"Mandu","species":"dog","weight":12.5}
                """, PetCreateRequest.class);
        assertEquals(new BigDecimal("12.5"), request.weight());

        PetCreateRequest withoutWeight = mapper.readValue("""
                {"name":"Mandu","species":"dog","weight":null}
                """, PetCreateRequest.class);
        assertEquals(null, withoutWeight.weight());
    }

    @Test
    void rejectsNumericStringsBeforeBigDecimalParsing() {
        assertThrows(Exception.class, () -> mapper.readValue("""
                {"name":"Mandu","species":"dog","weight":"1"}
                """, PetCreateRequest.class));
    }
}
