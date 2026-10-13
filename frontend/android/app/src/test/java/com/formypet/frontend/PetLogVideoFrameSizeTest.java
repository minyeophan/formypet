package com.formypet.frontend;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class PetLogVideoFrameSizeTest {
    @Test
    public void boundsVeryTallImageWithoutChangingItsAspectRatioMaterially() {
        int[] size = PetLogVideoFrameSize.fromSource(1000, 10000);

        assertEquals(192, size[0]);
        assertEquals(1920, size[1]);
        assertTrue((long) size[0] * size[1] <= PetLogVideoFrameSize.MAX_PIXELS);
    }

    @Test
    public void boundsWideImageAndKeepsDimensionsEven() {
        int[] size = PetLogVideoFrameSize.fromSource(5000, 3000);

        assertEquals(1080, size[0]);
        assertEquals(648, size[1]);
        assertEquals(0, size[0] % 2);
        assertEquals(0, size[1] % 2);
    }

    @Test
    public void acceptsTinyPositiveImagesAsValidCodecFrames() {
        int[] size = PetLogVideoFrameSize.fromSource(1, 1);

        assertEquals(2, size[0]);
        assertEquals(2, size[1]);
    }

    @Test(expected = IllegalArgumentException.class)
    public void rejectsInvalidDimensions() {
        PetLogVideoFrameSize.fromSource(0, 100);
    }
}
