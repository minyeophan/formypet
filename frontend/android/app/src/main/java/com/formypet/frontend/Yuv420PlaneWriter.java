package com.formypet.frontend;

import java.nio.ByteBuffer;

/** Writes ARGB pixels to Android's stride-aware YUV_420_888 input planes. */
final class Yuv420PlaneWriter {
    private Yuv420PlaneWriter() {}

    static void write(
            int[] pixels,
            int width,
            int height,
            ByteBuffer yPlane,
            int yRowStride,
            int yPixelStride,
            ByteBuffer uPlane,
            int uRowStride,
            int uPixelStride,
            ByteBuffer vPlane,
            int vRowStride,
            int vPixelStride) {
        if (width % 2 != 0 || height % 2 != 0 || pixels.length < width * height) {
            throw new IllegalArgumentException("YUV 4:2:0 requires an even frame and enough pixels.");
        }
        for (int row = 0; row < height; row++) {
            for (int column = 0; column < width; column++) {
                int color = pixels[row * width + column];
                int red = (color >> 16) & 0xff;
                int green = (color >> 8) & 0xff;
                int blue = color & 0xff;
                int y = ((66 * red + 129 * green + 25 * blue + 128) >> 8) + 16;
                yPlane.put(row * yRowStride + column * yPixelStride, clamp(y));
                if ((row & 1) == 0 && (column & 1) == 0) {
                    int u = ((-38 * red - 74 * green + 112 * blue + 128) >> 8) + 128;
                    int v = ((112 * red - 94 * green - 18 * blue + 128) >> 8) + 128;
                    uPlane.put((row / 2) * uRowStride + (column / 2) * uPixelStride, clamp(u));
                    vPlane.put((row / 2) * vRowStride + (column / 2) * vPixelStride, clamp(v));
                }
            }
        }
    }

    private static byte clamp(int value) {
        return (byte) Math.max(0, Math.min(255, value));
    }
}
