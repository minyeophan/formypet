package com.formypet.petlog;

import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class PetLogRequestValidationTest {
    @Test void acceptsOneToTenPhotosAndOptionalText() {
        assertDoesNotThrow(() -> new PetLogCreateRequest(LocalDate.now(), LocalTime.NOON, null, List.of(1L)));
        assertDoesNotThrow(() -> new PetLogCreateRequest(LocalDate.now(), LocalTime.NOON, "day", List.of(1L,2L,3L,4L,5L,6L,7L,8L,9L,10L)));
    }

    @Test void rejectsMissingOrTooManyPhotosAndLongText() {
        assertAll(
            () -> assertThrows(IllegalArgumentException.class, () -> new PetLogCreateRequest(LocalDate.now(), LocalTime.NOON, null, List.of())),
            () -> assertThrows(IllegalArgumentException.class, () -> new PetLogCreateRequest(LocalDate.now(), LocalTime.NOON, null, List.of(1L,2L,3L,4L,5L,6L,7L,8L,9L,10L,11L))),
            () -> assertThrows(IllegalArgumentException.class, () -> new PetLogCreateRequest(LocalDate.now(), LocalTime.NOON, null, List.of(1L, 1L))),
            () -> assertThrows(IllegalArgumentException.class, () -> new PetLogCreateRequest(LocalDate.now(), LocalTime.NOON, "x".repeat(2001), List.of(1L)))
        );
    }
}
