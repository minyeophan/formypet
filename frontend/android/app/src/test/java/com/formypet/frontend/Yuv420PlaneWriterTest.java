package com.formypet.frontend;

import static org.junit.Assert.assertEquals;

import java.nio.ByteBuffer;
import org.junit.Test;

public class Yuv420PlaneWriterTest {
    @Test
    public void writesPlanesUsingTheirIndependentRowAndPixelStrides() {
        int width = 2;
        int height = 2;
        int[] pixels = {0xffff0000, 0xff00ff00, 0xff0000ff, 0xffffffff};
        ByteBuffer y = ByteBuffer.allocate(8);
        ByteBuffer u = ByteBuffer.allocate(4);
        ByteBuffer v = ByteBuffer.allocate(4);

        Yuv420PlaneWriter.write(
                pixels, width, height,
                y, 4, 1,
                u, 4, 2,
                v, 4, 2);

        assertEquals(82, y.get(0) & 0xff);
        assertEquals(144, y.get(1) & 0xff);
        assertEquals(41, y.get(4) & 0xff);
        assertEquals(235, y.get(5) & 0xff);
        assertEquals(90, u.get(0) & 0xff);
        assertEquals(240, v.get(0) & 0xff);
        assertEquals(0, u.get(1) & 0xff);
    }
}
