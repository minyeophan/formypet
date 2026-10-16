package com.formypet.domain.media.storage;

import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.*;

class MediaImageDimensionsTest {
    private final MediaImageDimensions dimensions = new MediaImageDimensions();

    @Test
    void readsRealPngAndRejectsUnreadableData() throws Exception {
        var output = new ByteArrayOutputStream();
        ImageIO.write(new BufferedImage(3, 2, BufferedImage.TYPE_INT_RGB), "png", output);
        assertThat(dimensions.read(output.toByteArray())).containsExactly(3, 2);
        assertThatIllegalArgumentException().isThrownBy(() -> dimensions.read(new byte[]{1,2,3}))
                .withMessage("사진 파일을 읽을 수 없습니다.");
    }

    @Test
    void readsExtendedWebpFallbackAndEnforcesPixelLimit() throws Exception {
        assertThat(dimensions.read(webp(640,480))).containsExactly(640,480);
        assertThatIllegalArgumentException().isThrownBy(() -> dimensions.read(webp(10000,10000)))
                .withMessage("사진은 5천만 화소 이하로 선택해 주세요.");
    }

    private byte[] webp(int width, int height) {
        byte[] bytes = new byte[30];
        System.arraycopy("RIFF".getBytes(StandardCharsets.US_ASCII),0,bytes,0,4);
        System.arraycopy("WEBPVP8X".getBytes(StandardCharsets.US_ASCII),0,bytes,8,8);
        bytes[4]=22;
        bytes[16]=10;
        for(int i=0;i<3;i++) {
            bytes[24+i]=(byte)((width-1)>>(8*i));
            bytes[27+i]=(byte)((height-1)>>(8*i));
        }
        return bytes;
    }
}
