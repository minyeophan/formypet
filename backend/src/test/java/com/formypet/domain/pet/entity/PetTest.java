package com.formypet.domain.pet.entity;

import org.junit.jupiter.api.Test;
import java.time.LocalDate;
import static org.junit.jupiter.api.Assertions.*;

class PetTest {
    @Test
    void creationCyclesDefaultColorsAndPreservesExplicitColors() {
        var first = Pet.create(null, "Mochi", "dog", null, null, " ", 0);
        var next = Pet.create(null, "Mochi", "dog", null, null, null, 1);
        var wrapped = Pet.create(null, "Mochi", "dog", null, null, null, 10);
        assertEquals("#FF6B6B", first.getAccentColor());
        assertEquals("#FFE5E5", first.getBgLight());
        assertEquals("#4ECDC4", next.getAccentColor());
        assertEquals(first.getAccentColor(), wrapped.getAccentColor());
        var custom = Pet.create(null, "Mochi", "dog", null, "#123456", "#ABCDEF", 0);
        assertEquals("#123456", custom.getAccentColor());
        assertEquals("#ABCDEF", custom.getBgLight());
    }

    @Test
    void omittedBirthSpeciesAndBlankColorsKeepExistingValues() {
        var date = LocalDate.of(2022, 3, 15);
        var pet = Pet.create(null, "Mochi", "dog", date, null, null, 0);
        update(pet, null, null);
        assertEquals(date, pet.getBirthDate());
        assertEquals("dog", pet.getSpecies());
        assertEquals("#FF6B6B", pet.getAccentColor());
        assertEquals("#FFE5E5", pet.getBgLight());
    }

    @Test
    void unknownBirthDateOverridesSuppliedDateAndExplicitDateCanRestoreIt() {
        var pet = Pet.create(null, "Mochi", "dog", null, null, null, 0);
        var date = LocalDate.of(2022, 3, 15);
        update(pet, date, true);
        assertNull(pet.getBirthDate());
        update(pet, date, false);
        assertEquals(date, pet.getBirthDate());
    }

    private void update(Pet pet, LocalDate date, Boolean unknown) {
        pet.update("Mandu", null, date, unknown, null, null, null, null,
                null, null, null, null, null, null, null, null, " ", null);
    }
}
