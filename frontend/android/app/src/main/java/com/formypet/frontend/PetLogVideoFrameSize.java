package com.formypet.frontend;

/** Bounds codec work while keeping the first photo's aspect ratio. */
final class PetLogVideoFrameSize {
    static final int MAX_WIDTH = 1080;
    static final int MAX_HEIGHT = 1920;
    static final long MAX_PIXELS = 2_073_600L;

    private PetLogVideoFrameSize() {}

    static int[] fromSource(int sourceWidth, int sourceHeight) {
        if (sourceWidth < 1 || sourceHeight < 1) {
            throw new IllegalArgumentException("Photo dimensions must be positive.");
        }
        double scale = Math.min(
                1.0,
                Math.min(
                        Math.min((double) MAX_WIDTH / sourceWidth, (double) MAX_HEIGHT / sourceHeight),
                        Math.sqrt((double) MAX_PIXELS / ((double) sourceWidth * sourceHeight))));
        int width = evenAtLeastTwo((int) Math.floor(sourceWidth * scale));
        int height = evenAtLeastTwo((int) Math.floor(sourceHeight * scale));
        return new int[] {width, height};
    }

    private static int evenAtLeastTwo(int value) {
        int even = value & ~1;
        return Math.max(2, even);
    }
}
